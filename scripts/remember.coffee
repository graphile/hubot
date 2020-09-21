# Description
#   Remembers a key and value
#
# Commands:
#   hubot what is|remember <key> - Returns a string
#   hubot !<key> - Shortcut to remember
#   hubot remember <key> is <value>. - Returns nothing. Remembers the text for next time!
#   hubot what do you remember - Returns everything hubot remembers.
#   hubot forget <key> - Removes key from hubots brain.
#   hubot what are your favorite memories? - Returns a list of the most remembered memories.  
#   hubot random memory - Returns a random string
#
# Dependencies:
#   "underscore": "*"

_ = require('underscore')

module.exports = (robot) ->
  memoriesByRecollection = () -> robot.brain.data.memoriesByRecollection ?= {}
  memories = () -> robot.brain.data.remember ?= {}

  findSimilarMemories = (key) ->
    searchRegex = new RegExp(key, 'i')
    Object.keys(memories()).filter (key) -> searchRegex.test(key)

  handler = (msg) ->
    words = msg.match[1]
    if match = words.match /([a-z0-9-_:]+)(\s+is\s+([\s\S]*))$/i
      msg.finish()
      key = match[1].toLowerCase()
      value = match[3]
      currently = memories()[key]
      if currently
        msg.send "But #{key} is already #{currently}.  Forget #{key} first."
      else
        memories()[key] = value
        msg.send "OK, I'll remember #{key}."
    else if match = words.match /([a-z0-9-_:]+)\??/i
      msg.finish()

      key = match[1].toLowerCase()
      value = memories()[key]

      if value
        memoriesByRecollection()[key] ?= 0
        memoriesByRecollection()[key]++
      else
        if match = words.match /\|\s*(grep\s+)?(.*)$/i
          searchPattern = match[2]
          matchingKeys = findSimilarMemories(searchPattern)
          if matchingKeys.length > 0
            value = "I remember:\n#{matchingKeys.join('\n')}"
          else
            value = "I don't remember anything matching `#{searchPattern}`"
        else
          matchingKeys = findSimilarMemories(key)
          if matchingKeys.length > 0
            keys = matchingKeys.join('\n')
            value = "I don't remember `#{key}`. Did you mean:\n#{keys}"
          else
            value = "I don't remember anything matching `#{key}`"

      msg.send value

  robot.respond /(?:what is\s+|rem(?:ember)?\s+|!)([\s\S]*)/i, handler
  robot.hear /(?:^!)([a-z0-9-_:]+\??)$/i, handler
  robot.hear /(?:^!)([a-z0-9-_:]+\s+is\s+[\s\S]*)$/i, handler

  robot.respond /forget\s+(.*)/i, (msg) ->
    user = msg.message.user
    userId = user.id
    userName = "#{user.name}##{user.discriminator}"
    roomId = msg.message.room
    channel = msg.robot.client.channels.get(roomId)
    guildMember = channel.guild.members.get(userId)
    roles = guildMember.roles
    roleIds = Array.from(roles.keys())

    if roleIds.includes(process.env.ADMIN_ROLE_ID)
      key = msg.match[1].toLowerCase()
      value = memories()[key]
      delete memories()[key]
      delete memoriesByRecollection()[key]
      console.log "#{userName} told us to forget #{key} is #{value}."
      msg.send "I've forgotten #{key} is #{value}."
    else
      console.log("#{userName} has roles '#{roleIds.join("', '")}' which doesn't include '#{process.env.ADMIN_ROLE_ID}'")
      msg.send "Permission denied"

  robot.respond /what do you remember/i, (msg) ->
    msg.finish()
    keys = []
    keys.push key for key of memories()
    msg.send "I remember:\n#{keys.join('\n')}"

  robot.respond /what are your favorite memories/i, (msg) ->
    msg.finish()
    sortedMemories = _.sortBy Object.keys(memoriesByRecollection()), (key) ->
      memoriesByRecollection()[key]
    sortedMemories.reverse()

    msg.send "My favorite memories are:\n#{sortedMemories[0..20].join('\n')}"

  robot.respond /(me|random memory|memories)$/i, (msg) ->
    msg.finish()
    randomKey = msg.random(Object.keys(memories()))
    msg.send randomKey
    msg.send memories()[randomKey]

  robot.respond /mem(ory)? bomb x?(\d+)/i, (msg) ->
    keys = []
    keys.push value for key,value of memories()
    unless msg.match[2]
      count = 10
    else
      count = parseInt(msg.match[2])
    count = Math.min(10, count)

    msg.send(msg.random(keys)) for [1..count]
