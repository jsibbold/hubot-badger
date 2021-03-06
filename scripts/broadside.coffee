# Description:
#   Allows Hubot to post to BroadSide
#
# Dependencies:
#   None
#
# Configuration:
#   None
#
# Commands:
#   hubot broadside [URL]
#
# Author:
#   nwest
request = require "request"

module.exports = (robot) ->

  robot.respond /broadside panic/i, (msg) ->
    request.post("http://detroitlabs.broadsidetv.com/queue", {form: {panic: true}})

  robot.respond /broadside (.+)/i, (msg) ->
    url = msg.match[1]

    if url.match(/http\:\/\/(?:|.+).+\.(png|jpeg|jpg|gif)/i)
      msg.send "Adding " + msg.match[1] + " to the queue..."
      addToQueue(msg.match[1])
    else if url == "panic"
    else
      msg.send "I didn't recognize the image url"

  addToQueue = (url) ->
    email = 'nwest@detroitlabs.com'
    options =
      url:'http://detroitlabs.broadsidetv.com/image/queue/add'
      json:
        email:email
        url:url
        displayNow:0
        fitScreen:true
    req = request.post(options)
