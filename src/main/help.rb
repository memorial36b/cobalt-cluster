# Crystal: Help


# This crystal handels the +help command. This command takes into user permissions and send channel to automatically provide useful relavent and usefull information (i.e. showing only music commands in #music_vc)
module Bot::Help
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Constants

  # Help Command

  command(:help) do |event|
    
    # Check the channel ID the command was used in and filter based on channel groupings
    case event.channel.id
    
    # Check if event channel is a General Channel (non-creative, non-command, & non-moderator)
    when SERVER_FEEDBACK_CHANNEL_ID, EMOTE_SUGGESTIONS_CHANNEL_ID, GENERAL_CHANNEL_ID, MEME_CHANNEL_ID, SVTFOE_DISCUSSION_ID, SVTFOE_GALLERY_ID, ENTERTAINMENT_CHANNEL_ID, GAME_CHANNEL_ID, TECH_CHANNEL_ID, VENT_SPACE_CHANNEL_ID, DEBATE_CHANNEL_ID, ALPHABET_CHANNEL_ID, COUNTING_CHANNEL_ID, QUESTION_AND_ANSWER_CHANNEL_ID, WORD_ASSOCIATION_CHANNEL_ID, GENERAL_VC_CHANNEL_ID, GENERAL_VC_CHANNEL_ID, GAMING_VC_CHANNEL_ID, MOD_VC_CHANNEL_ID, MUTED_USERS_CHANNEL_ID
      if event.user.role?(ADMINISTRATOR_ROLE_ID)  
        
        event.user.dm.send_embed do |embed|
          
          embed.color = 0x00A1E2
          
          embed.author = {
              name: "Commands - Administrator",
              url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ?autoplay=1",
              icon_url: 'https://cdn.discordapp.com/icons/297550039125983233/d656bcf8febb57a73df83c1df951ed9e.png?size=2048'
          }
          embed.thumbnail = {
              url: "https://cdn.discordapp.com/app-icons/753190745426362368/992d8132d9d263ab83a39d272e871f29.png?size=2048"}
          
          embed.add_field(
              name: "Hrm...",
              value: "It appears there are no commands avaliable for use in <##{event.channel.id}> with your current role(s). Please try running +help in a channel with bot interaction such as <##{BOT_COMMANDS_CHANNEL_ID}>"
          )
          
          embed.image = {
              url: "https://media1.tenor.com/images/dfbd1d84c4c68a5186b186e6a4488357/tenor.gif?itemid=5247861"
          }

          embed.footer = {
              text: "Missing Commands? Try running +help in the relavent channel",
              icon_url: "https://cdn.discordapp.com/attachments/753163837057794176/805998319251882034/467450365055336448.png"
          }
        end
      
      elsif event.user.role?(MODERATOR_ROLE_ID)
        
        event.user.dm.send_embed do |embed|
          
          embed.color = 0xFF4D4D
          
          embed.author = {
              name: "Commands - Moderator",
              url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ?autoplay=1",
              icon_url: 'https://cdn.discordapp.com/icons/297550039125983233/d656bcf8febb57a73df83c1df951ed9e.png?size=2048'
          }
          embed.thumbnail = {
              url: "https://cdn.discordapp.com/app-icons/753190745426362368/992d8132d9d263ab83a39d272e871f29.png?size=2048"}
          
          embed.add_field(
              name: "Hrm...",
              value: "It appears there are no commands avaliable for use in <##{event.channel.id}> with your current role(s). Please try running +help in a channel with bot interaction such as <##{BOT_COMMANDS_CHANNEL_ID}>"
          )
          
          embed.image = {
              url: "https://media1.tenor.com/images/dfbd1d84c4c68a5186b186e6a4488357/tenor.gif?itemid=5247861"
          }

          embed.footer = {
              text: "Missing Commands? Try running +help in the relavent channel",
              icon_url: "https://cdn.discordapp.com/attachments/753163837057794176/805998319251882034/467450365055336448.png"
          }
        end

      elsif event.user.role?(HEAD_CREATOR_ROLE_ID)
        
        event.user.dm.send_embed do |embed|
          
          embed.color = 0x8C7EF0
          
          embed.author = {
              name: "Commands - Head Creator",
              url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ?autoplay=1",
              icon_url: 'https://cdn.discordapp.com/icons/297550039125983233/d656bcf8febb57a73df83c1df951ed9e.png?size=2048'
          }
          embed.thumbnail = {
              url: "https://cdn.discordapp.com/app-icons/753190745426362368/992d8132d9d263ab83a39d272e871f29.png?size=2048"}
          
          embed.add_field(
              name: "Hrm...",
              value: "It appears there are no commands avaliable for use in <##{event.channel.id}> with your current role(s). Please try running +help in a channel with bot interaction such as <##{BOT_COMMANDS_CHANNEL_ID}>"
          )
          
          embed.image = {
              url: "https://media1.tenor.com/images/dfbd1d84c4c68a5186b186e6a4488357/tenor.gif?itemid=5247861"
          }

          embed.footer = {
              text: "Missing Commands? Try running +help in the relavent channel",
              icon_url: "https://cdn.discordapp.com/attachments/753163837057794176/805998319251882034/467450365055336448.png"
          }
        end
     
      elsif COBALT_DEV_ID.include?(event.user.id)  
        
        event.user.dm.send_embed do |embed|
          
          embed.color = 0x65DDB7
          
          embed.author = {
              name: "Commands - Dev",
              url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ?autoplay=1",
              icon_url: 'https://cdn.discordapp.com/icons/297550039125983233/d656bcf8febb57a73df83c1df951ed9e.png?size=2048'
          }
          embed.thumbnail = {
              url: "https://cdn.discordapp.com/app-icons/753190745426362368/992d8132d9d263ab83a39d272e871f29.png?size=2048"}
          
          embed.add_field(
              name: "Hrm...",
              value: "It appears there are no commands avaliable for use in <##{event.channel.id}> with your current role(s). Please try running +help in a channel with bot interaction such as <##{BOT_COMMANDS_CHANNEL_ID}>"
          )
          
          embed.image = {
              url: "https://media1.tenor.com/images/dfbd1d84c4c68a5186b186e6a4488357/tenor.gif?itemid=5247861"
          }

          embed.footer = {
              text: "Missing Commands? Try running +help in the relavent channel",
              icon_url: "https://cdn.discordapp.com/attachments/753163837057794176/805998319251882034/467450365055336448.png"
          }
        end

      elsif event.user.role?(MEMBER_ROLE_ID)
        
        event.user.dm.send_embed do |embed|
          
          embed.color = 0x0047AB
          
          embed.author = {
              name: "Commands - Member",
              url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ?autoplay=1",
              icon_url: 'https://cdn.discordapp.com/icons/297550039125983233/d656bcf8febb57a73df83c1df951ed9e.png?size=2048'
          }
          embed.thumbnail = {
              url: "https://cdn.discordapp.com/app-icons/753190745426362368/992d8132d9d263ab83a39d272e871f29.png?size=2048"}
          
          embed.add_field(
              name: "Hrm...",
              value: "It appears there are no commands avaliable for use in <##{event.channel.id}> with your current role(s). Please try running +help in a channel with bot interaction such as <##{BOT_COMMANDS_CHANNEL_ID}>"
          )
          
          embed.image = {
              url: "https://media1.tenor.com/images/dfbd1d84c4c68a5186b186e6a4488357/tenor.gif?itemid=5247861"
          }

          embed.footer = {
              text: "Missing Commands? Try running +help in the relavent channel",
              icon_url: "https://cdn.discordapp.com/attachments/753163837057794176/805998319251882034/467450365055336448.png"
          }
        end
      end
      
    # Check if event channel is #head_creator_hq
    when HEAD_CREATOR_HQ_CHANNEL_ID
      
      # Check user role(s) (and ID in the case of Devs) and modify response(s) accordingly
      if event.user.role?(ADMINISTRATOR_ROLE_ID)
                
        event.send_embed do |embed|
          
          embed.color = 0x00A1E2
          
          embed.author = {
              name: "Commands - #head_creator_hq - Administrator",
              url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ?autoplay=1",
              icon_url: 'https://cdn.discordapp.com/icons/297550039125983233/d656bcf8febb57a73df83c1df951ed9e.png?size=2048'
          }
          embed.thumbnail = {
              url: "https://cdn.discordapp.com/app-icons/753190745426362368/992d8132d9d263ab83a39d272e871f29.png?size=2048"}
          
          embed.add_field(
              name: "+help",
              value: "Provde a list of commands relavent to the channel you run it in (i.e. music commands in <##{MUSIC_VC_CHANNEL_ID}>)"
          )
          
          embed.add_field(
              name: "+creator {add, remove} {art, writing, multimedia} [@username]",
              value: "Gives or removes the chosen creator role to/from the specificed user"
          )
          
          embed.add_field(
              name: "+punish [@username] [reason]",
              value: "Punish the specified user for breaking the rules"
          )
          
          embed.add_field(
              name: "+block [@username] [reason]",
              value: "Block's the selected user from being able to view or post in the channel the command was used in and gives the user 2 points."
          )
                    
          embed.add_field(
              name: "+unblock [@username]",
              value: "Unblock's the selected user from the channel the command was used in. Points added by the +block command must be removed manually using the +points command. Run +help in <##{MODERATION_CHANNEL_CHANNEL_ID}> for more information on the +points command"
          )
          embed.footer = {
              text: "Missing Commands? Try running +help in the relavent channel",
              icon_url: "https://cdn.discordapp.com/attachments/753163837057794176/805998319251882034/467450365055336448.png"
          }
        end     
      
      elsif event.user.role?(MODERATOR_ROLE_ID)
                
        event.send_embed do |embed|
          
          embed.color = 0xFF4D4D
          
          embed.author = {
              name: "Commands - #head_creator_hq - Moderator",
              url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ?autoplay=1",
              icon_url: 'https://cdn.discordapp.com/icons/297550039125983233/d656bcf8febb57a73df83c1df951ed9e.png?size=2048'
          }
          embed.thumbnail = {
              url: "https://cdn.discordapp.com/app-icons/753190745426362368/992d8132d9d263ab83a39d272e871f29.png?size=2048"}
          
          embed.add_field(
              name: "+help",
              value: "Provde a list of commands relavent to the channel you run it in (i.e. music commands in <##{MUSIC_VC_CHANNEL_ID}>)"
          )
          
          embed.add_field(
              name: "+creator {add, remove} {art, writing, multimedia} [@username]",
              value: "Gives or removes the chosen creator role to/from the specificed user"
          )
          
          embed.add_field(
              name: "+punish [@username] [reason]",
              value: "Punish the specified user for breaking the rules"
          )
          
          embed.add_field(
              name: "+block [@username] [reason]",
              value: "Block's the selected user from being able to view or post in the channel the command was used in and gives the user 2 points."
          )
                    
          embed.add_field(
              name: "+unblock [@username]",
              value: "Unblock's the selected user from the channel the command was used in. Points added by the +block command must be removed manually using the +points command. Run +help in <##{MODERATION_CHANNEL_CHANNEL_ID}> for more information on the +points command"
          )
          embed.footer = {
              text: "Missing Commands? Try running +help in the relavent channel",
              icon_url: "https://cdn.discordapp.com/attachments/753163837057794176/805998319251882034/467450365055336448.png"
          }
        end

      elsif event.user.role?(HEAD_CREATOR_ROLE_ID)
        
        event.send_embed do |embed|
          
          embed.color = 0x8C7EF0
          
          embed.author = {
              name: "Commands - #head_creator_hq - Head Creator",
              url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ?autoplay=1",
              icon_url: 'https://cdn.discordapp.com/icons/297550039125983233/d656bcf8febb57a73df83c1df951ed9e.png?size=2048'
          }
          embed.thumbnail = {
              url: "https://cdn.discordapp.com/app-icons/753190745426362368/992d8132d9d263ab83a39d272e871f29.png?size=2048"}
          
          embed.add_field(
              name: "+help",
              value: "Provde a list of commands relavent to the channel you run it in (i.e. music commands in <##{MUSIC_VC_CHANNEL_ID}>)"
          )
          
          embed.add_field(
              name: "+creator {add, remove} {art, writing, multimedia} [@username]",
              value: "Gives or removes the chosen creator role to/from the specificed user"
          )
          
          embed.add_field(
              name: "+punish [@username] [reason]",
              value: "Punish the specified user for breaking the rules. Punishments can only be minor (1-3 points). If a greater punishment is warrented/required, temporarially block the user with +block (see below) and either file a report with +report or message a mod/admin"
          )
          
          embed.add_field(
              name: "+block [@username] [reason]",
              value: "Block's the selected user from being able to view or post in the channel the command was used in and gives the user 2 points. Command only functions in <##{ORIGINAL_ART_CHANNEL_ID}> and <##{ORIGINAL_CONTENT_CHANNEL_ID}>"
          )
                    
          embed.add_field(
              name: "+unblock [@username]",
              value: "Unblock's the selected user from the channel the command was used in. Points added by the +block command will not be removed. Contact a mod or admin if points need to be removed"
          )
          embed.footer = {
              text: "Missing Commands? Try running +help in the relavent channel",
              icon_url: "https://cdn.discordapp.com/attachments/753163837057794176/805998319251882034/467450365055336448.png"
          }
        end
      end
    
    # Check if event channel is a creative channel
    when ORIGINAL_ART_CHANNEL_ID, ORIGINAL_CONTENT_CHANNEL_ID
      if event.user.role?(ADMINISTRATOR_ROLE_ID)
        
        event.user.dm.send_embed do |embed|
        
          embed.color = 0x00A1E2
          
          embed.author = {
              name: "Commands - #head_creator_hq - Administrator",
              url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ?autoplay=1",
              icon_url: 'https://cdn.discordapp.com/icons/297550039125983233/d656bcf8febb57a73df83c1df951ed9e.png?size=2048'
          }
          embed.thumbnail = {
              url: "https://cdn.discordapp.com/app-icons/753190745426362368/992d8132d9d263ab83a39d272e871f29.png?size=2048"}
          
          embed.add_field(
              name: "+help",
              value: "Provde a list of commands relavent to the channel you run it in (i.e. music commands in <##{MUSIC_VC_CHANNEL_ID}>)"
          )
          
          embed.add_field(
              name: "+creator {add, remove} {art, writing, multimedia} [@username]",
              value: "Gives or removes the chosen creator role to/from the specificed user - Must be used in <##{HEAD_CREATOR_HQ_CHANNEL_ID}>"
          )
          
          embed.add_field(
              name: "+punish [@username] [reason]",
              value: "Punish the specified user for breaking the rules"
          )
          
          embed.add_field(
              name: "+block [@username] [reason]",
              value: "Block's the selected user from being able to view or post in the channel the command was used in and gives the user 2 points."
          )
                    
          embed.add_field(
              name: "+unblock [@username]",
              value: "Unblock's the selected user from the channel the command was used in. Points added by the +block command must be removed manually using the +points command. Run +help in <##{MODERATION_CHANNEL_CHANNEL_ID}> for more information on the +points command"
          )
          embed.footer = {
              text: "Missing Commands? Try running +help in the relavent channel",
              icon_url: "https://cdn.discordapp.com/attachments/753163837057794176/805998319251882034/467450365055336448.png"
          }
        end          

      elsif event.user.role?(MODERATOR_ROLE_ID)
        
        event.user.dm.send_embed do |embed|          
          
          embed.color = 0xFF4D4D
            
          embed.author = {
              name: "Commands - #head_creator_hq - Moderator",
              url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ?autoplay=1",
              icon_url: 'https://cdn.discordapp.com/icons/297550039125983233/d656bcf8febb57a73df83c1df951ed9e.png?size=2048'
          }
          embed.thumbnail = {
              url: "https://cdn.discordapp.com/app-icons/753190745426362368/992d8132d9d263ab83a39d272e871f29.png?size=2048"}
          
          embed.add_field(
              name: "+help",
              value: "Provde a list of commands relavent to the channel you run it in (i.e. music commands in <##{MUSIC_VC_CHANNEL_ID}>)"
          )
          
          embed.add_field(
              name: "+creator {add, remove} {art, writing, multimedia} [@username]",
              value: "Gives or removes the chosen creator role to/from the specificed user - Must be used in <##{HEAD_CREATOR_HQ_CHANNEL_ID}>"
          )
          
          embed.add_field(
              name: "+punish [@username] [reason]",
              value: "Punish the specified user for breaking the rules"
          )
          
          embed.add_field(
              name: "+block [@username] [reason]",
              value: "Block's the selected user from being able to view or post in the channel the command was used in and gives the user 2 points."
          )
                    
          embed.add_field(
              name: "+unblock [@username]",
              value: "Unblock's the selected user from the channel the command was used in. Points added by the +block command must be removed manually using the +points command. Run +help in <##{MODERATION_CHANNEL_CHANNEL_ID}> for more information on the +points command"
          )
          embed.footer = {
              text: "Missing Commands? Try running +help in the relavent channel",
              icon_url: "https://cdn.discordapp.com/attachments/753163837057794176/805998319251882034/467450365055336448.png"
          }
        end
      
      elsif event.user.role?(HEAD_CREATOR_ROLE_ID)
                
        event.user.dm.send_embed do |embed|          
          
          embed.color = 0x8C7EF0
          
          embed.author = {
              name: "Commands - #head_creator_hq - Head Creator",
              url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ?autoplay=1",
              icon_url: 'https://cdn.discordapp.com/icons/297550039125983233/d656bcf8febb57a73df83c1df951ed9e.png?size=2048'
          }
          embed.thumbnail = {
              url: "https://cdn.discordapp.com/app-icons/753190745426362368/992d8132d9d263ab83a39d272e871f29.png?size=2048"}
          
          embed.add_field(
              name: "+help",
              value: "Provde a list of commands relavent to the channel you run it in (i.e. music commands in <##{MUSIC_VC_CHANNEL_ID}>)"
          )
          
          embed.add_field(
              name: "+creator {add, remove} {art, writing, multimedia} [@username]",
              value: "Gives or removes the chosen creator role to/from the specificed user - Must be used in <##{HEAD_CREATOR_HQ_CHANNEL_ID}>"
          )
          
          embed.add_field(
              name: "+punish [@username] [reason]",
              value: "Punish the specified user for breaking the rules. Punishments can only be minor (1-3 points). If a greater punishment is warrented/required, temporarially block the user with +block (see below) and either file a report with +report or message a mod/admin"
          )
          
          embed.add_field(
              name: "+block [@username] [reason]",
              value: "Block's the selected user from being able to view or post in the channel the command was used in and gives the user 2 points. Command only functions in <##{ORIGINAL_ART_CHANNEL_ID}> and <##{ORIGINAL_CONTENT_CHANNEL_ID}>"
          )
                    
          embed.add_field(
              name: "+unblock [@username]",
              value: "Unblock's the selected user from the channel the command was used in. Points added by the +block command will not be removed. Contact a mod or admin if points need to be removed"
          )
          embed.footer = {
              text: "Missing Commands? Try running +help in the relavent channel",
              icon_url: "https://cdn.discordapp.com/attachments/753163837057794176/805998319251882034/467450365055336448.png"
          }
        end          
      end
    
    # Check if event channel is #bot_commands
    when BOT_COMMANDS_CHANNEL_ID
      if event.user.role?(ADMINISTRATOR_ROLE_ID)
                
        event.user.dm.send_embed do |embed|
                
          embed.color = 0x00A1E2
          
          embed.author = {
              name: "Commands - #bot_commands - Administrator",
              url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ?autoplay=1",
              icon_url: 'https://cdn.discordapp.com/icons/297550039125983233/d656bcf8febb57a73df83c1df951ed9e.png?size=2048'
          }
          embed.thumbnail = {
              url: "https://cdn.discordapp.com/app-icons/753190745426362368/992d8132d9d263ab83a39d272e871f29.png?size=2048"}
          
          embed.add_field(
              name: "+help",
              value: "Provde a list of commands relavent to the channel you run it in (i.e. music commands in <##{MUSIC_VC_CHANNEL_ID}>)"
          )
          
          embed.add_field(
              name: "+punish [@username] [reason]",
              value: "Punish the specified user for breaking the rules. Punishments can be Minor (1-3 points), Major (5-7 points), or Critical (10-12 points). Punishments automatically scale based on user's existing undecayed point total. In the event a user reaches one of the point thresholds (this threshold varies depending on the current point total and the severity of the infraction) to be the user will be muted and put on trial for ban. As an administrator you can just select :white_check_mark: to approve the ban without secondary approval"
          )

          embed.add_field(
              name: "+ban [@username] [reason]",
              value: "Puts the selected user on trial and gives you the option to prune the user's messages. As an administrator you can just select :white_check_mark: to approve the ban without secondary approval"
          )

          embed.add_field(
              name: "+say",
              value: "Makes Cobalt Butterfly say whatever you want. **DO NOT ABUSE THIS**. Try to keep Cobalt in character when utilizing this feature"
          )

          embed.footer = {
              text: "Missing Commands? Try running +help in the relavent channel",
              icon_url: "https://cdn.discordapp.com/attachments/753163837057794176/805998319251882034/467450365055336448.png"
          }
        end
      end
          
      if event.user.role?(MODERATOR_ROLE_ID)
                
        event.user.dm.send_embed do |embed|
                
          embed.color = 0xFF4D4D
          
          embed.author = {
              name: "Commands - #bot_commands - Moderator",
              url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ?autoplay=1",
              icon_url: 'https://cdn.discordapp.com/icons/297550039125983233/d656bcf8febb57a73df83c1df951ed9e.png?size=2048'
          }
          embed.thumbnail = {
              url: "https://cdn.discordapp.com/app-icons/753190745426362368/992d8132d9d263ab83a39d272e871f29.png?size=2048"}
          
          embed.add_field(
              name: "+help",
              value: "Provde a list of commands relavent to the channel you run it in (i.e. music commands in <##{MUSIC_VC_CHANNEL_ID}>)"
          )
          
          embed.add_field(
              name: "+punish [@username] [reason]",
              value: "Punish the specified user for breaking the rules. Punishments can be Minor (1-3 points), Major (5-7 points), or Critical (10-12 points). Punishments automatically scale based on user's existing undecayed point total. In the event a user reaches one of the point thresholds (this threshold varies depending on the current point total and the severity of the infraction) to be the user will be muted and put on trial for ban. Another moderator or administrator is required for the ban to be approved"
          )
                    
          embed.add_field(
              name: "+points {check}",
              value: "Enables you to check your point totals. This can be run in either <##{BOT_COMMANDS_CHANNEL_ID}> or <##{MODERATION_CHANNEL_CHANNEL_ID}>. For extended moderator options see below"
          )
                              
          embed.add_field(
              name: "+points {check, add, remove} [#] [@username]",
              value: "Use this command to check the points of other users as well as to modify the point totals of the other user. Adding or removing points through this command does not apply or remove a scaling punishment. The add/remove function of this command should only be used to correct point errors or for other miscellaneous purposes (i.e. a user sucessfully appeals a ban but you would like them to have a starting balance of 10 points). Everything else should go through +punish - This command must be run in <##{MODERATION_CHANNEL_CHANNEL_ID}>"
          ) 
                              
          embed.add_field(
              name: "+points decay {off, reset} [@username]",
              value: "This function enables you to disable (off) or re-enable (reset) point decay for a user. Point decay causes points to slowly fall at a rate of 1 point every 2 weeks. Point decay encourages good behavior and should not be disabled unless a user is demonstrably abusing the system - This command must be run in <##{MODERATION_CHANNEL_CHANNEL_ID}>"
          ) 

          embed.add_field(
              name: "+mute [@username, channel] [time s,m,h,d] [reason]",
              value: "Mutes either a user or an entire text channel for the specified period of time. If muting a channel, the text 'channel' must be used and the command must be run in the channel being muted. Mutes do not give users points. If points are warrented the +punish command should be used instead"
          )
                    
          embed.add_field(
              name: "+unmute [@username, channel]",
              value: "Unmutes either the selected user or a text channel. If unmuting a channel, the text 'channel' must be used and the command must be run in the channel being muted"
          )          
          
          embed.add_field(
              name: "+muted [users, channels]",
              value: "Returns a list of either muted users or muted channels - Must be used in either <##{MODERATION_CHANNEL_CHANNEL_ID}> or <##{MUTED_USERS_CHANNEL_ID}>"
          )
                    
          embed.add_field(
              name: "+unblock [@username]",
              value: "Unblock's the selected user from the channel the command was used in. Points added by +block are not removed automatically with +unblock. These points can be removed manually with +points"
          )
                    
          embed.add_field(
              name: "+block [@username] [reason]",
              value: "Block's the selected user from being able to view or post in the channel the command was used in and gives the user 2 points"
          )
                    
          embed.add_field(
              name: "+blocks",
              value: "Returns a list of user blocks"
          )
                              
          embed.add_field(
              name: "+ban [@username] [reason]",
              value: "Puts the selected user on trial and gives you the option to prune the user's messages. Another admin or moderator will be required to approve the ban"
          )
                              
          embed.add_field(
              name: "+prune [2-100]",
              value: "Prunes a specific number of messages from a channel. WARNING: This command does NOT look at who sent the message when deleting"
          )

          embed.add_field(
              name: "+ping",
              value: "Checks the bot's response time"
          )

          embed.add_field(
              name: "+roleping {updates, svtfoenews, svtfoeleaks}",
              value: "Enables pinging the specificed role through Cobalt without needing to deal with mentionable permissions"
          )
          
          embed.add_field(
              name: "+quality",
              value: "reserved for 'quality' SVTFOE discussions - <##{SVTFOE_DISCUSSION_ID}> exclusive command"
          )
        
          embed.add_field(
              name: "+bean [@username] [optional reason]",
              value: "**Beans** a user from the server"
          )
      
          embed.add_field(
              name: "+birthday {check, set, delete, next} [mm/dd] [@username]",
              value: "If you set your birthday, Cobalt will give you a special role for the occassion. You can also check who's birthday is next. As a moderator you can also check, modify, delete, or add birthdays for other users"
          )

          embed.add_field(
            name: "+fine [@username] {small, medium, large}",
            value: "Fine a user for bad behavior."
          )

          embed.footer = {
              text: "Missing Commands? Try running +help in the relavent channel",
              icon_url: "https://cdn.discordapp.com/attachments/753163837057794176/805998319251882034/467450365055336448.png"
          }
        end
      end

      if COBALT_DEV_ID.include?(event.user.id)
                
        event.user.dm.send_embed do |embed|
                
          embed.color = 0x65DDB7
          
          embed.author = {
              name: "Commands - #bot_commands - Dev",
              url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ?autoplay=1",
              icon_url: 'https://cdn.discordapp.com/icons/297550039125983233/d656bcf8febb57a73df83c1df951ed9e.png?size=2048'
          }
          embed.thumbnail = {
              url: "https://cdn.discordapp.com/app-icons/753190745426362368/992d8132d9d263ab83a39d272e871f29.png?size=2048"}
          
          embed.add_field(
              name: "+ping",
              value: "Checks the bot's response time"
          )
          
          embed.add_field(
              name: "+build",
              value: "Checks the build and build revision of Cobalt"
          )
          
          embed.add_field(
              name: "+testserver",
              value: "Sends a temporary invite link to the SVTFOE Cobalt Test Server. This link will self-destruct after 10 seconds"
          )
          
          embed.add_field(
              name: "+ded",
              value: "server be ded"
          )
                    
          embed.add_field(
              name: "+quality",
              value: "reserved for 'quality' SVTFOE discussions - <##{SVTFOE_DISCUSSION_ID}> exclusive command"
          )
          
          embed.add_field(
              name: "+say",
              value: "Makes Cobalt Butterfly say whatever you want. **DO NOT ABUSE THIS**. Try to keep Cobalt in character when utilizing this feature"
          )
                    
          embed.add_field(
              name: "+exit",
              value: "Cobalt's kill switch. Only use in case of emergencies (i.e. a moderator account is compromised)"
          )

          embed.add_field(
              name: "+debugprofile [optional @username]",
              value: "Display more in depth debug information about a user's economy profile."
          )

          embed.add_field(
              name: "+lastcheckin [optional @username]",
              value: "Check when the specified user last checked in."
          )

          embed.add_field(
              name: "+inventory [optional @username]",
              value: "Display all of the items in a user's inventory."
          )

          embed.add_field(
              name: "+econdummy",
              value: "Force a database cleaning of your banking profile. Note: This doesn't delete your account; it removes expired temp balances."
          )

          embed.footer = {
              text: "Missing Commands? Try running +help in the relavent channel",
              icon_url: "https://cdn.discordapp.com/attachments/753163837057794176/805998319251882034/467450365055336448.png"
          }
        end
      end

      if event.user.role?(MEMBER_ROLE_ID)
        
        event.send_embed do |embed|
          
          embed.color = 0x0047AB
          
          embed.author = {
              name: "Commands - #bot_commands",
              url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ?autoplay=1",
              icon_url: 'https://cdn.discordapp.com/icons/297550039125983233/d656bcf8febb57a73df83c1df951ed9e.png?size=2048'
          }
          embed.thumbnail = {
              url: "https://cdn.discordapp.com/app-icons/753190745426362368/992d8132d9d263ab83a39d272e871f29.png?size=2048"}
          
          embed.add_field(
              name: "+help",
              value: "Provde a list of commands relavent to the channel you run it in (i.e. music commands in <##{MUSIC_VC_CHANNEL_ID}>)"
          )

          embed.add_field(
              name: "+helpshop",
              value: "Provide a list of commands relavent to Cobalt's Shop. These commands can only be used here."
          )
          
          embed.add_field(
              name: "+birthday {check, set, delete, next} [mm/dd]",
              value: "If you set your birthday, Cobalt will give you a special role for the occassion. You can also check who's birthday is next"
          )
          
          embed.add_field(
              name: "+report",
              value: "Is another user causing a ruckus? Use +report to bring the issue to the server mods and admins. This command should be used in the channel where the issue is occuring"
          )
          
          embed.add_field(
              name: "+hug [@username]",
              value: "Someone else having a rough day. Help cheer them up with a hug! Can also be used in: <##{VENT_SPACE_CHANNEL_ID}> and <##{GENERAL_CHANNEL_ID}>"
          )
                    
          embed.add_field(
              name: "+boop [@username]",
              value: "Boops another user"
          )
                    
          embed.add_field(
              name: "+listboops",
              value: "Lists boops"
          )
                    
          embed.add_field(
            name: "+points",
            value: "Did you mess up? (you did) Use this command to check how many points you have and when a point you recieved will decay. For information on points and point decay please read the punishments section in <##{ADDITIONAL_INFO_CHANNEL_ID}>"
          )
                                        
          embed.add_field(
            name: "+bean",
            value: '¯\_(ツ)_/¯'
          )
          
          embed.footer = {
              text: "Missing Commands? Try running +help in the relavent channel",
              icon_url: "https://cdn.discordapp.com/attachments/753163837057794176/805998319251882034/467450365055336448.png"
          }
        end
      end
    
    # Check if event channel is #bot_games
    when BOT_GAME_CHANNEL_ID
      if event.user.role?(MEMBER_ROLE_ID)
        event.respond "Bot Games - For game commands use !help in <##{BOT_GAME_CHANNEL_ID}>"
      end
    
    # Check if event channel is #music_vc
    when MUSIC_VC_CHANNEL_ID    
      if event.user.role?(MODERATOR_ROLE_ID)
        event.user.dm "For moderator specific commands please refer to the music bot's documentation"
        end
      if event.user.role?(MEMBER_ROLE_ID)
        event.respond "For music commands please check the pinned message in <##{MUSIC_VC_CHANNEL_ID}>"
      end
    
    # Check if event channel is #moderation_channel
    when MODERATION_CHANNEL_CHANNEL_ID
      if event.user.role?(ADMINISTRATOR_ROLE_ID)
                
        event.send_embed do |embed|
                
          embed.color = 0x00A1E2
          
          embed.author = {
              name: "Commands - #bot_commands - Administrator",
              url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ?autoplay=1",
              icon_url: 'https://cdn.discordapp.com/icons/297550039125983233/d656bcf8febb57a73df83c1df951ed9e.png?size=2048'
          }
          embed.thumbnail = {
              url: "https://cdn.discordapp.com/app-icons/753190745426362368/992d8132d9d263ab83a39d272e871f29.png?size=2048"}
          
          embed.add_field(
              name: "+help",
              value: "Provde a list of commands relavent to the channel you run it in (i.e. music commands in <##{MUSIC_VC_CHANNEL_ID}>)"
          )
          
          embed.add_field(
              name: "+punish [@username] [reason]",
              value: "Punish the specified user for breaking the rules. Punishments can be Minor (1-3 points), Major (5-7 points), or Critical (10-12 points). Punishments automatically scale based on user's existing undecayed point total. In the event a user reaches one of the point thresholds (this threshold varies depending on the current point total and the severity of the infraction) to be the user will be muted and put on trial for ban. As an administrator you can just select :white_check_mark: to approve the ban without secondary approval"
          )

          embed.add_field(
              name: "+ban [@username] [reason]",
              value: "Puts the selected user on trial and gives you the option to prune the user's messages. As an administrator you can just select :white_check_mark: to approve the ban without secondary approval"
          )

          embed.add_field(
              name: "+say",
              value: "Makes Cobalt Butterfly say whatever you want. **DO NOT ABUSE THIS**. Try to keep Cobalt in character when utilizing this feature"
          )

          embed.footer = {
              text: "Missing Commands? Try running +help in the relavent channel",
              icon_url: "https://cdn.discordapp.com/attachments/753163837057794176/805998319251882034/467450365055336448.png"
          }
        end
      end
          
      if event.user.role?(MODERATOR_ROLE_ID)
                
        event.send_embed do |embed|
                
          embed.color = 0xFF4D4D
          
          embed.author = {
              name: "Commands - #bot_commands - Moderator",
              url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ?autoplay=1",
              icon_url: 'https://cdn.discordapp.com/icons/297550039125983233/d656bcf8febb57a73df83c1df951ed9e.png?size=2048'
          }
          embed.thumbnail = {
              url: "https://cdn.discordapp.com/app-icons/753190745426362368/992d8132d9d263ab83a39d272e871f29.png?size=2048"}
          
          embed.add_field(
              name: "+help",
              value: "Provde a list of commands relavent to the channel you run it in (i.e. music commands in <##{MUSIC_VC_CHANNEL_ID}>)"
          )
          
          embed.add_field(
              name: "+punish [@username] [reason]",
              value: "Punish the specified user for breaking the rules. Punishments can be Minor (1-3 points), Major (5-7 points), or Critical (10-12 points). Punishments automatically scale based on user's existing undecayed point total. In the event a user reaches one of the point thresholds (this threshold varies depending on the current point total and the severity of the infraction) to be the user will be muted and put on trial for ban. Another moderator or administrator is required for the ban to be approved"
          )
                    
          embed.add_field(
              name: "+points {check}",
              value: "Enables you to check your point totals. This can be run in either <##{BOT_COMMANDS_CHANNEL_ID}> or <##{MODERATION_CHANNEL_CHANNEL_ID}>. For extended moderator options see below"
          )
                              
          embed.add_field(
              name: "+points {check, add, remove} [#] [@username]",
              value: "Use this command to check the points of other users as well as to modify the point totals of the other user. Adding or removing points through this command does not apply or remove a scaling punishment. The add/remove function of this command should only be used to correct point errors or for other miscellaneous purposes (i.e. a user sucessfully appeals a ban but you would like them to have a starting balance of 10 points). Everything else should go through +punish - This command must be run in <##{MODERATION_CHANNEL_CHANNEL_ID}>"
          ) 
                              
          embed.add_field(
              name: "+points decay {off, reset} [@username]",
              value: "This function enables you to disable (off) or re-enable (reset) point decay for a user. Point decay causes points to slowly fall at a rate of 1 point every 2 weeks. Point decay encourages good behavior and should not be disabled unless a user is demonstrably abusing the system - This command must be run in <##{MODERATION_CHANNEL_CHANNEL_ID}>"
          ) 

          embed.add_field(
              name: "+mute [@username, channel] [time s,m,h,d] [reason]",
              value: "Mutes either a user or an entire text channel for the specified period of time. If muting a channel, the text 'channel' must be used and the command must be run in the channel being muted. Mutes do not give users points. If points are warrented the +punish command should be used instead"
          )
                    
          embed.add_field(
              name: "+unmute [@username, channel]",
              value: "Unmutes either the selected user or a text channel. If unmuting a channel, the text 'channel' must be used and the command must be run in the channel being muted"
          )          
          
          embed.add_field(
              name: "+muted [users, channels]",
              value: "Returns a list of either muted users or muted channels - Must be used in either <##{MODERATION_CHANNEL_CHANNEL_ID}> or <##{MUTED_USERS_CHANNEL_ID}>"
          )
                    
          embed.add_field(
              name: "+unblock [@username]",
              value: "Unblock's the selected user from the channel the command was used in. Points added by +block are not removed automatically with +unblock. These points can be removed manually with +points"
          )
                    
          embed.add_field(
              name: "+block [@username] [reason]",
              value: "Block's the selected user from being able to view or post in the channel the command was used in and gives the user 2 points"
          )
                    
          embed.add_field(
              name: "+blocks",
              value: "Returns a list of user blocks"
          )
                              
          embed.add_field(
              name: "+ban [@username] [reason]",
              value: "Puts the selected user on trial and gives you the option to prune the user's messages. Another admin or moderator will be required to approve the ban"
          )
                              
          embed.add_field(
              name: "+prune [2-100]",
              value: "Prunes a specific number of messages from a channel. WARNING: This command does NOT look at who sent the message when deleting"
          )

          embed.add_field(
              name: "+ping",
              value: "Checks the bot's response time"
          )

          embed.add_field(
              name: "+roleping {updates, svtfoenews, svtfoeleaks}",
              value: "Enables pinging the specificed role through Cobalt without needing to deal with mentionable permissions"
          )
          
          embed.add_field(
              name: "+quality",
              value: "reserved for 'quality' SVTFOE discussions - <##{SVTFOE_DISCUSSION_ID}> exclusive command"
          )
        
          embed.add_field(
              name: "+bean [@username] [optional reason]",
              value: "**Beans** a user from the server"
          )
      
          embed.add_field(
              name: "+birthday {check, set, delete, next} [mm/dd] [@username]",
              value: "If you set your birthday, Cobalt will give you a special role for the occassion. You can also check who's birthday is next. As a moderator you can also check, modify, delete, or add birthdays for other users"
          )

          embed.footer = {
              text: "Missing Commands? Try running +help in the relavent channel",
              icon_url: "https://cdn.discordapp.com/attachments/753163837057794176/805998319251882034/467450365055336448.png"
          }
        end
      end

      if COBALT_DEV_ID.include?(event.user.id)
                
        event.user.dm.send_embed do |embed|
                
          embed.color = 0x65DDB7
          
          embed.author = {
              name: "Commands - #bot_commands - Dev",
              url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ?autoplay=1",
              icon_url: 'https://cdn.discordapp.com/icons/297550039125983233/d656bcf8febb57a73df83c1df951ed9e.png?size=2048'
          }
          embed.thumbnail = {
              url: "https://cdn.discordapp.com/app-icons/753190745426362368/992d8132d9d263ab83a39d272e871f29.png?size=2048"}
          
          embed.add_field(
              name: "+ping",
              value: "Checks the bot's response time"
          )
          
          embed.add_field(
              name: "+build",
              value: "Checks the build and build revision of Cobalt"
          )
          
          embed.add_field(
              name: "+testserver",
              value: "Sends a temporary invite link to the SVTFOE Cobalt Test Server. This link will self-destruct after 10 seconds"
          )
          
          embed.add_field(
              name: "+ded",
              value: "server be ded"
          )
                    
          embed.add_field(
              name: "+quality",
              value: "reserved for 'quality' SVTFOE discussions - <##{SVTFOE_DISCUSSION_ID}> exclusive command"
          )
          
          embed.add_field(
              name: "+say",
              value: "Makes Cobalt Butterfly say whatever you want. **DO NOT ABUSE THIS**. Try to keep Cobalt in character when utilizing this feature"
          )
                    
          embed.add_field(
              name: "+exit",
              value: "Cobalt's kill switch. Only use in case of emergencies (i.e. a moderator account is compromised)"
          )

          embed.footer = {
              text: "Missing Commands? Try running +help in the relavent channel",
              icon_url: "https://cdn.discordapp.com/attachments/753163837057794176/805998319251882034/467450365055336448.png"
          }
        end
      end
    
    # All other event channels (and DMs)
    else
      event.user.dm.send_embed do |embed|
          
        embed.color = 0x0047AB
        
        embed.author = {
            name: "Commands - Unknown",
            url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ?autoplay=1",
            icon_url: 'https://cdn.discordapp.com/icons/297550039125983233/d656bcf8febb57a73df83c1df951ed9e.png?size=2048'
        }
        embed.thumbnail = {
            url: "https://cdn.discordapp.com/app-icons/753190745426362368/992d8132d9d263ab83a39d272e871f29.png?size=2048"}
        
        embed.add_field(
            name: "Hrm...",
            value: "It appears there are no commands avaliable for use in <##{event.channel.id}>. Please try running +help in a channel with bot interaction such as <##{BOT_COMMANDS_CHANNEL_ID}>"
        )
        
        embed.image = {
            url: "https://media1.tenor.com/images/dfbd1d84c4c68a5186b186e6a4488357/tenor.gif?itemid=5247861"
        }

        embed.footer = {
            text: "Missing Commands? Try running +help in the relavent channel",
            icon_url: "https://cdn.discordapp.com/attachments/753163837057794176/805998319251882034/467450365055336448.png"
        }
      end
    end
  end

  # Economy Help Command
  command(:helpshop) do |event|
    break unless event.channel.id == BOT_COMMANDS_CHANNEL_ID
    event.send_embed do |embed|    
      embed.color = 0x0047AB
      embed.author = {
          name: "Cobalt's Shop Commands - #bot_commands",
          url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ?autoplay=1",
          icon_url: 'https://cdn.discordapp.com/icons/297550039125983233/d656bcf8febb57a73df83c1df951ed9e.png?size=2048'
      }
      embed.thumbnail = {
          url: "https://cdn.discordapp.com/app-icons/753190745426362368/992d8132d9d263ab83a39d272e871f29.png?size=2048"
      }

      embed.add_field(
          name: "+helpshop",
          value: "Provide a list of commands relavent to Cobalt's Shop. These commands can only be used here."
      )

      embed.add_field(
        name: "+settimezone [timezone name]",
        value: "Set the timezone you live in."
      )

      embed.add_field(
        name: "+gettimezone",
        value: "Check what timezone Cobalt thinks you live in."
      )

      embed.add_field(
        name: "+shop",
        value: "See all of the items currently available in Cobalt's Shop."
      )

      embed.add_field(
        name: "+profile [optional @username]",
        value: "Check your or someone else's Shop profile. See how much money they have and what they've bought."
      )

      embed.add_field(
        name: "+checkin",
        value: "Get your daily free Starbucks."
      )

      embed.add_field(
        name: "+richest",
        value: "See a list of the richest users."
      )

      embed.add_field(
        name: "+transfermoney [@username]",
        value: "Send Starbucks to another user."
      )

      embed.add_field(
        name: "+rentarole [role name]",
        value: "Rent a role that changes the color of your username."
      )

      embed.add_field(
        name: "+unrentarole",
        value: "Remove your rented role."
      )

      embed.add_field(
        name: "+tag {add, edit, delete} [tag name]",
        value: "Buy or manage tags that send a custom message."
      )

      embed.add_field(
        name: "+tags [optional @username]",
        value: "Search through all of the tags on the server or all of the ones belonging to a particular user."
      )

      embed.add_field(
        name: "+mycom {add, edit, delete, list} [command name]",
        value: "Buy or manage your custom commands."
      )

      embed.add_field(
        name: "+raffle {buyticket, reminder}",
        value: "Buy raffle tickets and get reminders about when new raffles start."
      )

      embed.footer = {
          text: "Missing Commands? Try running +help in the relavent channel",
          icon_url: "https://cdn.discordapp.com/attachments/753163837057794176/805998319251882034/467450365055336448.png"
      }
    end
  end
end