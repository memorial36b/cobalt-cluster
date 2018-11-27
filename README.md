# Cluster: A Clunky, Shoddily-Made, Cobbled-Together and Convoluted Modular Bot Framework for Discordrb

Cluster is a modular bot framework I made for [discordrb](https://github.com/meew0/discordrb), partially inspired by [gemstone](https://github.com/z64/gemstone).

I really only made it for two reasons:

* To get my own personal bot projects more organized
* To arm-wrestle with Yellow Diamond while the Crystal Gems deal with Blue

All individual modules, called crystals, are located in the `src/crystals` directory. The main folder contains all the crystals that are loaded by default, and the dev folder contains crystals that will be loaded either by themselves or alongside the main crystals as desired.

## Instructions

To run a bot, fill in `config.yml` with all the necessary information and then execute `ruby run.rb` on the command line. It will automatically load all crystals present in the `src/crystals/main` directory. To run crystals present in the `src/crystals/dev` directory, execute `ruby run.rb -d` for dev crystals exclusively and `ruby run.rb -a` to run both main and dev crystals. (`run.rb` contains a shebang, so you can also set it to executable and run `./run.rb` if you desire)

## Installing a crystal

Simply drag the `crystal_name.rb` file into the `src/modules/main` directory and run the bot as normal. If a data folder is also included, drag the contents of it to the `data` folder; do the same for `lib` if it is included as well.

## Developing a crystal

For development of crystals, a simple crystal template generator is included in `src/crystals`. Simply run `generate.rb` with the name of your template as a command line argument, and a crystal starter will be generated.

### Additional files

If a crystal you are developing needs additional files to be loaded, they should be placed in the `lib` directory; all files in this directory are loaded prior to loading the crystals within the `Bot` module.