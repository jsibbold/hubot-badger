# Description:
#   Janky API integration. https://github.com/github/janky
#
# Dependencies:
#   None
#
# Configuration:
#   HUBOT_JANKY_URL
#
# Commands:
#   hubot ci - show usage
#
# Author:
#   sr

URL  = require "url"
url  = URL.parse(process.env.HUBOT_JANKY_URL)
HTTP = require(url.protocol.replace(/:$/, ""))

defaultOptions = () ->
  auth = new Buffer(url.auth).toString("base64")
  template =
    host: url.hostname
    port: url.port || 80
    path: url.pathname
    headers:
      "Authorization": "Basic #{auth}"

get = (path, params, cb) ->
  options = defaultOptions()
  options.path += path
  console.log(options)
  req = HTTP.request options, (res) ->
    body = ""
    res.setEncoding("utf8")
    res.on "data", (chunk) ->
      body += chunk
    res.on "end", () ->
      cb null, res.statusCode, body
  req.on "error", (e) ->
    console.log(e)
    cb e, 500, "Client Error"
  req.end()

put = (path, params, cb) ->
  post path, params, cb, 'PUT'

post = (path, params, cb, method='POST') ->
  bodyParams     = JSON.stringify params

  options        = defaultOptions()
  options.path   = "/_hubot/#{path}"
  options.method = method
  options.headers['Content-Length'] = bodyParams.length

  req = HTTP.request options, (res) ->
    body = ""
    res.setEncoding("utf8")
    res.on "data", (chunk) ->
      body += chunk
    res.on "end", () ->
      cb null, res.statusCode, body
  req.on "error", (e) ->
    console.log(e)
    cb e, 500, "Client Error"
  req.end(bodyParams)
	
parseCIStatus = (text) ->
  linesArray = text.split /\n/
  finalArray = []
  data = []
  for line in linesArray
    rowArray = line.split /\s+/
    while rowArray.length > 4
      rowArray[1] += " " + rowArray[2]
      rowArray.splice(2,1)	
    data.push 
      name: rowArray[0] 
      status: rowArray[1]
      prettyName: rowArray[2]
      repo: rowArray[3]	
  broadsideItem = 
    moduleType: "cinderStatus"
    email: "cinderbot@detroitlabs.com"
    url: ""
    timeToLive: 0
    data: data
	
# BROADSIDE
broadsideOptions = () ->
	template =
		host: "alpha.detroitlabs.com"
		port: 3000
		method: "POST"
		headers:
			"Content-Type": "application/json"
			
postBroadside = (options, params, cb) ->
    bodyParams = JSON.stringify(params)
    req = HTTP.request options, (res) ->
      body = ""
      res.setEncoding("utf8")
      res.on "data", (chunk) ->
        body += chunk
      res.on "end", () ->
        cb null, res.statusCode, body
    req.on "error", (e) ->
      console.log(e)
      cb e, 500, "Client Error"
    req.end(bodyParams)
	
postBroadsideQueue = (params) ->
	options = broadsideOptions()
	options.path = "/queue/add"
	postBroadside options, params, (err, statusCode, body) ->
		console.log "Post image response status code: " + statusCode
		
postBroadsideOverride = (params, cb) ->
	options = broadsideOptions()
	options.path = "/queue/override"
	postBroadside options, params, (err, statusCode, body) ->
		console.log "Post image response status code: " + statusCode
		
		

module.exports = (robot) ->
  robot.respond /ci\??$/i, (msg) ->
    get "help", { }, (err, statusCode, body) ->
      if statusCode == 200
        msg.send body
      else
        msg.reply "can't help you right now."

  robot.respond /ci build ([-_\.0-9a-zA-Z]+)(\/([-_\.a-zA-z0-9\/]+))?/i, (msg) ->
    app     = msg.match[1]
    branch  = msg.match[3] || "master"
    room_id = msg.message.user.room
    user    = msg.message.user.name.replace(/\ /g, "+")

    post "#{app}/#{branch}?room_id=#{room_id}&user=#{user}", {}, (err, statusCode, body) ->
      if statusCode == 201 or statusCode == 404
        response = body
      else
        console.log body
        response = "Can't go HAM on #{app}/#{branch}, shit's being weird."

      msg.send response

  robot.respond /ci setup ([\.\-\/_a-z0-9]+)(\s?([\.\-_a-z0-9]+))?(\s?([\.\-_a-z0-9]+))?/i, (msg) ->
    nwo     = msg.match[1]
    params  = "?nwo=#{nwo}"
    if msg.match[3] != undefined
      params += "&name=#{msg.match[3]}"
      if msg.match[5] != undefined
        params += "&template=#{msg.match[5]}"

    post "setup#{params}", {}, (err, statusCode, body) ->
      if statusCode == 201
        msg.reply body
      else
        msg.reply "Error F7U12: Can't Setup."

  robot.respond /ci toggle ([-_\.0-9a-zA-Z]+)/i, (msg) ->
    app    = msg.match[1]

    post "toggle/#{app}", { }, (err, statusCode, body) ->
      if statusCode == 200
        msg.send body
      else
        msg.reply "failed to flip the flag.  Sorry."

  robot.respond /ci set room ([-_0-9a-zA-Z\.]+) (.*)$/i, (msg) ->
    repo = msg.match[1]
    room = encodeURIComponent(msg.match[2])
    put "#{repo}?room=#{room}", {}, (err, statusCode, body) ->
      if [404, 403, 200].indexOf(statusCode) > -1
        msg.send body
      else
        msg.send "you broke everything"

  robot.respond /ci rooms$/i, (msg) ->
    get "rooms", { }, (err, statusCode, body) ->
      if statusCode == 200
        rooms = JSON.parse body
        msg.reply rooms.join ", "
      else
        msg.reply "can't predict rooms now."

  robot.respond /ci status$/i, (msg) ->
    get "", {}, (err, statusCode, body) ->
      if statusCode == 200
        bodyObject= parseCIStatus body
        bodyObject.timeToLive = 30000
        postBroadsideOverride bodyObject
        msg.send(body)
      else
        msg.send("who knows")

  robot.respond /ci status (-v )?([-_\.0-9a-zA-Z]+)(\/([-_\.a-zA-z0-9\/]+))?/i, (msg) ->
    app    = msg.match[2]
    count  = 5
    branch = msg.match[4] || 'master'

    unless msg.match[1]?
      count = 1

    get "#{app}/#{branch}?limit=#{count}", { }, (err, statusCode, body) ->
      response = ""
      builds = JSON.parse(body)

      builds.forEach (build) ->
        response += "Build ##{build.number} (#{build.sha1}) of #{build.repo}/#{build.branch} #{build.status}"
        response += "(#{build.duration}s) #{build.compare}"
        response += "\n" if count > 1

      msg.send response

  robot.router.post "/janky", (req, res) ->
    get "", {}, (err, statusCode, body) ->
      if statusCode == 200
        bodyObject = parseCIStatus body
        bodyObject.timeToLive = 45000
        postBroadsideOverride bodyObject
    robot.messageRoom req.body.room, req.body.message
    res.end "ok"
