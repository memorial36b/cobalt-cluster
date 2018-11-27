# Cluster: src/crystals

This is the crystal folder. To install a crystal for use, drag the `.rb` file to the `main` folder within this one.

To generate a new crystal, run `ruby generate.rb <CrystalName>` (the file has a shebang, so you can make it executable and run `./generate.rb <CrystalName>` as well). The crystal name must have no spaces and be in CamelCase to work with the script! The script automatically handles naming the file correctly as the main script needs. The generated crystal is found in the `dev` folder, and can be run through `ruby run.rb -d` in the root directory, or `ruby run.rb -a` to run alongside your main modules.