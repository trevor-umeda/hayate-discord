# Description:
#   Retrieve embarassing tagsfrom your co-workers out of context!
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
#   hubot howmany <query> - Return the number of tagsthat contain each word of <query>.
#   hubot reload tags- Reload the quote file.
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
  tags = null

  # Read configuration from the environment.
  tagUrl = "https://vast-castle-1062.herokuapp.com/tags"
  imgUrl = "http://vast-castle-1062.herokuapp.com/image?tag="

  reloadThen = (callback) ->
    unless tagUrl?
      tags = []
      return

    robot.http(tagUrl)
    .get() (err, res, body) ->
      if res.statusCode is 200
        tags = JSON.parse(body)
      else
        tags = []
      callback(null)

  isLoaded = (msg) ->
    if tags?
      true
    else
      msg.reply "Just a moment, the tags aren't loaded yet."
      false

  queryFrom = (msg, matchNumber = 0) ->
    if msg.match[matchNumber]?
      words = msg.match[matchNumber].trim().split /\s+/
    else
      words = ['']
    _.filter words, (part) -> part.length > 0

  tagsMatching = (query = [], speakers = [], mentions = []) ->
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

  robot.hear /.*/i, (msg) ->
    parsedSentence = queryFrom msg

    if parsedSentence.length <= 5
      if (parsedSentence.length == 1)
        foundTags = _.intersection(parsedSentence, tags);
        if foundTags.length > 0
          robot.http(imgUrl + foundTags[0])
          .get() (err, res, body) ->
            if res.statusCode is 200
              robot.logger.info "#{body}"
              msg.send "#{body}"
            else
              tags = []
      else if (parsedSentence.length > 1)
        for tag in tags
          if(msg.match[0].trim().indexOf(tag) == 0 or msg.match[0].trim().indexOf(" " + tag) > 0)            
            formattedTag = tag.replace(/%20/g, "%20")
            robot.http(imgUrl + tag)
            .get() (err, res, body) ->
              if res.statusCode is 200
                robot.logger.info "#{body}"
                msg.send "#{body}"
              else
                tags = []
            break

#      if (body.find(word) >= 0 and ((len(words)==1 and (word in words)) or ( len(words) > 1 and (body.find(word+" ")==0) or (" "+word+" " in body) or (body.find(" "+word)==(wordsLength-len(word)-1))))):
#                    command_name = "omu"
#                    command_args = [word.replace (" ", "%20")]
#                    self.run_commands(command_name,command_args,msg,status,'true')

  robot.hear /quote(\s.*)?$/i, (msg) ->
    return unless isLoaded(msg)

    potential = tagsMatching queryFrom msg

    if potential.length > 0
      chosen = _.random potential.length - 1
      msg.send potential[chosen]
    else
      msg.send "That wasn't notable enough to quote. Try harder."

  robot.hear /quoteabout\s+@?(\S+)(\s+.*)?$/i, (msg) ->
    return unless isLoaded(msg)

    mentions = msg.match[1].split('+')
    query = queryFrom msg, 2

    potential = tagsMatching query, null, mentions

    if potential.length > 0
      chosen = _.random potential.length - 1
      msg.send potential[chosen]
    else
      m = "No tagsabout "

      if mentions.length is 1
        m += mentions[0]
      else if mentions.length is 2
        m += "both #{mentions[0]} and #{mentions[1]}"
      else
        m += "all of #{mentions.join ', '}"

      if query.length > 0
        m += " about that"

      msg.send m + '.'

  robot.hear /reload tags$/i, (msg) ->
    reloadThen (err) ->
      if err?
        msg.send "Oh, snap! Something blew up."
        msg.send err.stack
      else
        msg.send "#{tags.length} tags loaded successfully."
