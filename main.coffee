fs = require('fs')
Website = require('./index.js')
yaml = require('yamljs')


config = yaml.load("config.yml")
websites = []

for w in config.websites
    site = new Website(w)
    websites.push(site)

    console.log("Starting loop for: #{w.name}")

    site.mainLoop(config.globalConfig.desiredRegex, (url, data) ->
        name = (new RegExp(w.filename.exp)).match(url)[w.filename.index]
        fs.writeFileSync("found/#{name}.txt", data)
        console.log("[#{w.name}] Found relevant data in paste: #{url} | Saved to found/#{name}.txt")
    )