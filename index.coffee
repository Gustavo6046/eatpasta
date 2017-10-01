###
+----------+
| EatPasta |
+----------+

Your favorite paste website S&S system in Node.JS:
Searching and Scraping

©2017 Gustavo6046. The MIT license.
###

request = require('request')
fs = require('fs')
cheerio = require('cheerio')


resolveURL = (url, base) ->
    if not /^[a-z0-9]+:\/\//i.test(base)
        base = "http://" + base

    return (new (require('url').URL)(url, base)).href

if !(resolveURL("sub", "example.com") == "http://example.com/sub")
    throw new Error("[debug] Function resolveURL does not work!")

#==========================
# cheerio Filters
#==========================


# https://stackoverflow.com/a/2419877/5129091 (adapted)
cheerio.prototype.outerHTML = (s) ->
    if s
        @before(s).remove()
        
    else
        cheerio('<p>').append(@eq(0).clone()).html()


#==========================
# Main Code!
#==========================
ior = (l) ->
    return l.reduce((a, b) -> a or b)

getPage = (uri) ->
    return new Promise((resolve, reject) ->
        request.get({
            uri: uri
        }, (error, response, body) ->
            if response.statusCode != 200
                error = new Error("Status code #{response.statusCode}!")

            if error
                reject(error)

            else
                resolve(body)
        )
    )

class Website
    constructor: (@config) ->

    getArchive: =>
        return getPage(@config.archiveURL)

    individualPage: (url) =>
        config = @config

        return new Promise((resolve, reject) ->
            getPage(url).then(((body) ->
                $ = cheerio.load(body)

                next = ($, cpath, cpi, url) ->
                    query = cpath[cpi].contentQuery

                    if cpath[cpi].queryType is "link"
                        if cpath[cpi].queryIndex?
                            if not $(query)[cpath[cpi].queryIndex]?
                                fs.writeFileSync("#{query}\n#{$(query)}\n#{cpath[cpi].queryIndex}", "debug.log")

                            url = resolveURL($(query)[cpath[cpi].queryIndex].attribs["href"], url)

                        else
                            url = resolveURL($(query).attribs["href"], url)

                        getPage(url).then(
                            ((data) ->
                                if cpi == cpath.length - 1
                                    resolve({ data: data, url: url })

                                else
                                    next(cheerio.load(data), cpath, cpi + 1, url)
                            ),

                            ((error) ->
                                console.log(error)
                                reject(error)
                            )
                        )

                    else if cpath[cpi].queryType is "element"
                        if cpath[cpi].queryIndex?
                            el = $(query)[cpath[cpi].queryIndex]

                        else
                            el = $(query)

                        next(cheerio.load(el.outerHTML()), cpath, cpi + 1)

                next($, config.pathToContent, 0, url)
            ),

            ((error) ->
                console.log(error)
                reject(error)
            ))
        )

    individualPageHTML: (body, lastURL) =>
        config = @config

        $ = cheerio.load(body)

        return new Promise((resolve, reject) ->
            next = ($, cpath, cpi, url) ->
                query = cpath[cpi].contentQuery

                if cpath[cpi].queryType is "link"
                    if cpath[cpi].queryIndex?
                        url = resolveURL($(query)[cpath[cpi].queryIndex].attribs["href"], url)

                    else
                        url = resolveURL($(query).attribs["href"], url)

                    getPage(url).then(
                        ((data) ->
                            if cpi == cpath.length - 1
                                resolve({ data: data, url: url })

                            else
                                next(cheerio.load(data), cpath, cpi + 1, url)
                        ),

                        ((error) ->
                            reject(error)
                        )
                    )

                else if cpath[cpi].queryType is "element"
                    if cpath[cpi].queryIndex?
                        el = $(query)[cpath[cpi].queryIndex]

                    else
                        el = $(query)

                    next(cheerio.load(el.outerHTML()), cpath, cpi + 1, url)

            next($, config.pathToContent, 0, lastURL)
        )

    scrapePages: (callback) =>
        config = @config
        individualPage = @individualPage
        getArchive = @getArchive

        return new Promise((resolve, reject) ->
            errors  = []

            getArchive().then(
                ((data) ->
                    $ = cheerio.load(data)

                    links = $(config.individualPaste.selector)
                    console.log("[#{config.name}] Found #{links.length} candidates to pastes.")

                    if config.individualPaste.type is "link"
                        for l in links
                            i = 0

                            if l?
                                setTimeout((-> individualPage(resolveURL(l.attribs["href"], config.archiveURL)).then(
                                    ((res) ->
                                        callback(res.url, res.data)
                                    )

                                    ((error) ->
                                        reject(error)
                                    )
                                )), config.cooldowns.perLink * i) # to make sure a large amount of links does not result in ban

                                i++

                    else if config.individualPaste.type is "element"
                        for l in links
                            individualPageHTML(l.outerHTML(), config.archiveURL)
                ),

                ((error) ->
                    reject(error)
                )
            )
        )

    mainLoop: (desired, callback) =>
        scraped = []
        old = 0
        scrapePages = @scrapePages
        config = @config

        if (typeof desired) == "string"
            desired = new RegExp(desired, "ig")

        numErrors = 0

        scrape = ->
            scrapePages((url, data) ->
                if url not in scraped and desired.test(data)
                    callback(url, data)

                    scraped.push(url)

                if scraped.length == old
                    setTimeout(scrape, config.cooldowns.noNewPaste * 1000)

                else
                    console.log("[#{config.name}] Found #{scraped.length - old} new matching pastes this cycle!")

                    old = scraped.length
                    setTimeout(scrape, config.cooldowns.newPaste * 1000)

            ).then(
                () ->

                (error) ->
                    if numErrors == 5
                        throw error

                    else
                        console.log("Error during scraping (total 5 errors to give up):")
                        console.log(error)
                        numErrors++
            )
        
        scrape()

module.exports = Website