# eatpasta

is a Pastebin (and other websites) recent content scraper.

## How to use

Edit your `config.yml` file: locate

    globalConfig:
        desiredRegex: "((?:\\d{1:3}\\.){3}\\d{1:3})"

and replace `desiredRegex` by a regex of your preference.

Now run:

    node --trace-warnings main.js

'Nuff said.