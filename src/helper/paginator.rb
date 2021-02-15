# Database Discord Paginator
# Breaks down large query results into smaller digestible pages that
# the user can rotate through and perform queries on. The results
# are displayed as embeds with the results limited to the class
# defined maximum.

# Intermediate that Paginator consumes to create embed fields in the 
# results page. This must be created by the lambda passed to Paginator.
class PaginatorField
  # Create a paginator digestible field.
  # Note: It is an error to initialize either field as nil or empty.
  # @param [String] name  Non-nil, non-empty name.
  # @param [String] value Non-nil, non-empty value
  def initialize(field_name, field_value)
    @field_name  = field_name
    @field_value = field_value

    raise ArgumentError, "Invalid field or name specified for PaginatorField!" if
      @field_name  == nil || @field_name.empty?  || 
      @field_value == nil || @field_value.empty?
  end

  # Get the name.
  # @return The field's name.
  def field_name
    return @field_name
  end

  # Get the value.
  # @return The field's value.
  def field_value
    return @field_value
  end
end

# Create instances of this to paginate results.
# Note: Class enforces single threaded pagination handling and is not designed
# to be thread safe.
class Paginator
  include Convenience
  include Constants

  # The maximum number of results per page as enforced by Discord embeds.
  MAX_RESULTS_PER_PAGE = 25

  # The default number of results per page.
  DEFAULT_RESULTS_PER_PAGE = 10


  # How long in seconds to wait for a response before assuming query is dead.
  PAGINATOR_TIMEOUT = 3*60

  # Additional Member Variables:
  # [Integer]            @current_page_index   The currently displayed page index, which is used to compute offset.
  # [Integer]            @query_result_count   The total number of results for the current query.
  # [Discordrb::Message] @last_results_message The last sent embed, used to delete previous results to avoid clutter.
  # [bool]               @running              Whether the paginator is still running.

  # Construct a new Paginator.
  # @param [Discordrb::Channel] channel                  The channel to paginate results on.
  # @param [Hash]               embed_author             Results page author.
  # @param [String]             embed_title              Results page title.
  # @param [String]             embed_description        Results page description.
  # @param [Hash]               embed_thumbnail          Results page thumbnail, can be nil.
  # @param [Sequel::Dataset]    dataset                  The data set to query.
  # @param [Symbol]             query_column             The column that queries are performed against.
  # @param [bool]               force_queries_lowercase  Should queries be forced to lower case?
  # @param [Lambda]             row_hash_to_field_lambda A lambda that converts result table hashes to PaginatorFields.
  # @param [String]             initial_query            The initial query to start with, nil means no filter.
  # @param [Integer]            results_per_page         The number of results to display per page.
  def initialize(channel, embed_author, embed_title, embed_description, 
                 embed_thumbnail, dataset, query_column, force_queries_lowercase, 
                 row_hash_to_field_lambda, initial_query = nil, 
                 results_per_page = DEFAULT_RESULTS_PER_PAGE)
    @channel                  = channel
    @embed_author             = embed_author
    @embed_title              = embed_title
    @embed_description        = embed_description
    @embed_thumbnail          = embed_thumbnail
    @dataset                  = dataset
    @query_column             = query_column
    @force_queries_lowercase  = force_queries_lowercase
    @row_hash_to_field_lambda = row_hash_to_field_lambda
    @current_query            = initial_query 
    @results_per_page         = min(results_per_page, MAX_RESULTS_PER_PAGE)
    @current_page_index       = 0
    @query_result_count       = 0
    @last_results_message     = nil

    # validate inputs
    raise ArgumentError, "Invalid inputs received for paginator!" if 
      @embed_author == nil || @embed_title == nil || @embed_description == nil ||
      @channel == nil || @dataset == nil || @query_column == nil ||
      @row_hash_to_field_lambda == nil

    # enforce query casing if necessary
    @current_query = @current_query.downcase if 
      not(@current_query.nil?) and @force_queries_lowercase
  end

  # Run the paginator.
  def run()
    @running = true
    while @running 
      results = query()
      display_results(results)
      await_and_process_input()
    end
  end

  protected
  # Perform current query from current offset and store results.
  # @return [Array<Hash>] The results.
  def query()    
    # collect query data
    query_data = nil
    if @current_query == nil || @current_query.empty?
      query_data = @dataset.order(@query_column)
    else
      query_data = @dataset.where(Sequel.like(@query_column, 
        "%#{@current_query}%")).order(@query_column)
    end

    @query_result_count = query_data.count
    query_data          = query_data.offset(table_offset).limit(@results_per_page).all

    return query_data
  end

  # Send the curret results to the channel.
  # @param [Array<Hash> The results to display.
  def display_results(results)
    # create locally understood fields
    fields = results.map{ |result| @row_hash_to_field_lambda.call(result) }
    raise RuntimeError, "Too many results received!" if 
      fields.count > @results_per_page

    # delete previous results to avoid clutter
    if @last_results_message != nil
      begin
        @last_results_message.delete
        @last_results_message = nil
      rescue
        # insufficient permissions
      end
    end

    # send message
    @last_results_message = @channel.send_embed do |embed|
      embed.author      = @embed_author
      embed.title       = @embed_title
      embed.description = @embed_description
      embed.thumbnail   = @embed_thumbnail
      embed.color       = COLOR_EMBED # from Constants

      footer_text  = "Page #{current_page}/#{page_count}"
      footer_text += " Query: \"#{@current_query}\"" if @current_query != nil
      embed.footer = { text: footer_text } 

      # generate controls
      embed.description += "\n\nControls:\n"
      embed.description += "n - next page\n" if current_page < page_count
      embed.description += "p - prevous page\n" if current_page > 1
      embed.description += "g - goto page\n" if page_count > 1
      embed.description += 
        "q - new search\n" +
        "c - clear search\n" +
        "e - exit/stop"

      if fields.empty?
        embed.add_field(
          name: "Error",
          value: "No results found, try a new query.",
          inline: true
        )
      else
        fields.each do |field|
          embed.add_field(
            name:   field.field_name,
            value:  field.field_value,
            inline: true
          )
        end
      end
    end
  end

  # Wait for user input and then process it.
  def await_and_process_input()
    # todo: filter by a specific user
    response = @channel.await!({timeout: PAGINATOR_TIMEOUT})
    return nil if timed_out?(response)

    # process input
    user = response.user
    input = response.message.content
    case input.downcase
    when 'n', 'next', 'next page'
      if current_page < page_count
        @current_page_index += 1
      else
        msg = "#{user.mention}, sorry you're already on the last page."
        @channel.send_temporary_message(msg, 5)
      end
    when 'p', 'prev', 'previous', 'previous page' 
      if current_page > 1
        @current_page_index -= 1
      else
        msg = "#{user.mention}, sorry you're already on the last page."
        @channel.send_temporary_message(msg, 5)
      end
    when 'g', 'goto', 'go to', 'goto page', 'go to page'
      @current_page_index = ask_for_new_page_number()
    when 'q', 'query', 'search'
      @current_query = ask_for_new_query()
      @current_page_index = 0
    when 'c', 'clear', 'clear search', 'clear query'
      @current_query = nil
      @current_page_index = 0
    when 'e', 's', 'exit', 'stop', 'quit'
      @running = false
    else
      msg = "#{user.mention}, sorry I didn't get that."
      @channel.send_temporary_message(msg, 5)
    end
  end

  # Ask the user for a new page number.
  # @return the new page index.
  def ask_for_new_page_number()
    message = @channel.send_message("What page would you like to go to?")
    # todo: filter by a specific user
    response = @channel.await!({timeout: PAGINATOR_TIMEOUT})
    
    begin
      return @current_page_index if timed_out?(response)

      input = response.message.content
      begin
        new_page = Integer(input)
        return clamp(new_page, 1, page_count) - 1
      rescue
        msg = "Sorry, I didn't quite get that. Please try again."
        @channel.send_temporary_message(msg, 5)
        return @current_page_index
      end
    ensure
      begin
        # prevent chat polution, order is important, second can fail
        message.delete
        response.message.delete if response.message != nil
      rescue
        # lack permissions to delete
      end
    end
  end

  # Ask the user for a new query.
  # @param the new page number
  def ask_for_new_query()
    message = @channel.send_message("What would you like to search for?")
    response = @channel.await!({timeout: PAGINATOR_TIMEOUT})
    
    begin
      return nil if timed_out?(response)
      @current_query = response.message.content
      @current_query = @current_query.downcase if @force_queries_lowercase
      return @current_query
    ensure
      begin
        # prevent chat polution, order is important, second can fail
        message.delete 
        response.message.delete if response.message != nil
      rescue
        # insufficient permissions
      end
    end
  end

  # Check if an await timed out.
  # Note: This will send a message if it did and kill the paginator.
  # @param the value returned by await
  # @return [bool] Did it time out?
  def timed_out?(await_response)
    # check if timed out 
    if await_response == nil || await_response.message == nil || 
       await_response.user == nil
      timeout_msg = "I haven't heard from you in a bit so I'm stopping your search."
      @channel.send_temporary_message(timeout_msg, 30)
      
      @running = false
      return true
    else
      return false
    end
  end

  # Convenience: Get current offset in results.
  # @return offset in table
  def table_offset
    return @current_page_index * @results_per_page
  end

  # Convenience: Converts page index to actual page number.
  # @return page number
  def current_page
    return @current_page_index + 1
  end

  # Convenience: Get current page count.
  # @return query page count.
  def page_count
    count = @query_result_count / @results_per_page
    count += 1 if (@query_result_count % @results_per_page) > 0
    return count
  end
end