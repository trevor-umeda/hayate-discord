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

  addRole = (roleName, userName) ->
    server = _.find robot.adapter.client.servers, (server) -> server.name == 'Barnes Theater'
    role = _.find server.roles, (role) -> role.name == roleName
    sender = _.find server.members, (user) -> user.username == userName
    robot.adapter.client.addMemberToRole(sender, role)
    robot.logger.info "Adding role #{role.name} to #{sender.name}. Thankyou for contributing"

  sleep = (ms) ->
    start = new Date().getTime()
    continue while new Date().getTime() - start < ms

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
    #We will only do this on a short sentence
    if parsedSentence.length <= 5
      #If the sentence is one word, our job is easy
      if (parsedSentence.length == 1)
        #Find the intersection: find what tags were in the sentence
        foundTags = _.intersection(parsedSentence, tags);
        if foundTags.length > 0
          #Get a random image to post and then post it
          robot.http(imgUrl + foundTags[0])
          .get() (err, res, body) ->
            if res.statusCode is 200
              robot.logger.info "#{body}"
              msg.send "#{body}"
            else
              tags = []
      else if (parsedSentence.length > 1)
        #For ever tag, see if it is in the sentence
        for tag in tags
          sentenceString = msg.match[0].trim()
          if(sentenceString.indexOf(tag) >= 0)
            if(sentenceString.indexOf(tag + " ") == 0 or sentenceString.indexOf(" " + tag) == (sentenceString.length - tag.length - 1) or sentenceString.indexOf(" " + tag + " ") > 0)
              #Do a ghetto uri encoding of the tag
              formattedTag = tag.replace(/%20/g, "%20")
              #Get a random image from server and post it!
              robot.http(imgUrl + tag)
              .get() (err, res, body) ->
                if res.statusCode is 200
                  robot.logger.info "#{tag} - #{body}"
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

  robot.hear /^(?=.*?ben)(?=.*?love live)(?=.*?church).*$/, (msg) ->
    server = _.find robot.adapter.client.servers, (server) -> server.name == 'Barnes Theater'
    sender = _.find server.members, (user) -> user.username == msg.message.user.name
    role = _.find server.roles, (role) -> role.name == "Idol Thief"
    if !robot.adapter.client.memberHasRole(sender, role)
      #addRole "Idol Thief", msg.message.user.name
      channel = _.find server.channels, (channel) -> channel.name == 'palace'
      sleep 2000
      #robot.logger.info "Sending welcome message"
      #robot.adapter.client.sendMessage channel, sender + " Welcome..."
      #robot.adapter.client.sendMessage channel, "..Bzt.."

  robot.hear /reload tags$/i, (msg) ->
    #@robot.logger.info robot.adapter.client.servers[0].roles
    addRole "Contributor", msg.message.user.name
    reloadThen (err) ->
      if err?
        msg.send "Oh, snap! Something blew up."
        msg.send err.stack
      else
        msg.send "#{tags.length} tags loaded successfully."
