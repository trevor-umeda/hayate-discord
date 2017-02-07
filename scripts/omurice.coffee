# Description:
#   Retrieve embarassing quotes from your co-workers out of context!
#
# Dependencies:
#   underscore, moment.js
#
# Configuration:
#   HUBOT_QUOTEFILE_PATH The location of the quotefile.
#
# Commands:
#   hubot quote - Retrieve a random quote.
#   hubot quote <query> - Retrieve a random quote that contains each word of <query>.
#   hubot quoteby <username> [<query>] - Retrieve a random quote including a line spoken by <username>.
#   hubot quoteabout <username> [<query>] - Retrieve a random quote including a line addressing <username>.
#   hubot howmany <query> - Return the number of quotes that contain each word of <query>.
#   hubot reload quotes - Reload the quote file.
#   hubot quotestats - Show who's been quoted the most!
#   hubot verbatim quote: [...] - Enter a quote into the quote file exactly as given.
#   hubot slackapp quote: [...] - Parse a quote from the Slack app's paste format.
#   hubot buffer quote - Enter a quote from the buffer.
#
# Author:
#   smashwilson

fs = require 'fs'
_ = require 'underscore'

module.exports = (robot) ->

  # Global state.
  quotes = null

  # Read configuration from the environment.
  quotefilePath = process.env.HUBOT_QUOTEFILE_PATH

  reloadThen = (callback) ->
    unless quotefilePath?
      quotes = []
      return

    fs.readFile quotefilePath, encoding: 'utf-8', (err, data) ->
      if err?
        callback(err)
        return

      quotes = data.split /\n\n/
      quotes = _.filter quotes, (quote) -> quote.length > 1
      callback(null)

  isLoaded = (msg) ->
    if quotes?
      true
    else
      msg.reply "Just a moment, the quotes aren't loaded yet."
      false

  quotesMatching = (query = [], speakers = [], mentions = []) ->
    results = quotes

    if speakers.length > 0 or mentions.length > 0
      results = _.filter results, (quote) ->
        speakersNotSeen = new Set(speakers)
        mentionsNotSeen = new Set(mentions)

        for line in quote.split /\n/
          m = line.match /^\[[^\]]+\] @?([^:]+): (.*)$/
          if m?
            [x, speaker, rest] = m
            speakersNotSeen.delete(speaker)
            for mention in mentions
              mentionsNotSeen.delete(mention) if rest.includes mention

        speakersNotSeen.size is 0 and mentionsNotSeen.size is 0

    if query.length > 0
      rxs = (new RegExp(q, 'i') for q in query)
      results = _.filter results, (quote) ->
        _.every rxs, (rx) -> rx.test(quote)

      results

    results

  # Perform the initial load.
  reloadThen ->

  robot.hear /quote(\s.*)?$/i, (msg) ->
    return unless isLoaded(msg)

    potential = quotesMatching queryFrom msg

    if potential.length > 0
      chosen = _.random potential.length - 1
      msg.send potential[chosen]
    else
      msg.send "That wasn't notable enough to quote. Try harder."

  robot.hear /quoteabout\s+@?(\S+)(\s+.*)?$/i, (msg) ->
    return unless isLoaded(msg)

    mentions = msg.match[1].split('+')
    query = queryFrom msg, 2

    potential = quotesMatching query, null, mentions

    if potential.length > 0
      chosen = _.random potential.length - 1
      msg.send potential[chosen]
    else
      m = "No quotes about "

      if mentions.length is 1
        m += mentions[0]
      else if mentions.length is 2
        m += "both #{mentions[0]} and #{mentions[1]}"
      else
        m += "all of #{mentions.join ', '}"

      if query.length > 0
        m += " about that"

      msg.send m + '.'

  robot.hear /reload quotes$/i, (msg) ->
    msg.send "Reloading the quotes now"
    reloadThen (err) ->
      if err?
        msg.send "Oh, snap! Something blew up."
        msg.send err.stack
      else
        msg.send "#{quotes.length} quotes loaded successfully."
