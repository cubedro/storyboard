http = require 'http'
path = require 'path'
chalk = require 'chalk'
bodyParser = require 'body-parser'
storyboard = require '../src/storyboard'        # you'd write: `'storyboard'`
wsServer = require '../src/listeners/wsServer'  # you'd write: `'storyboard/listeners/wsServer'`
{mainStory} = storyboard

PORT = 3000

# Initialise our server
mainStory.info 'server', 'Initialising server...'
express = require 'express'
app = express()
app.use bodyParser.json()
app.use bodyParser.urlencoded {extended: true}
app.use express.static path.join(__dirname, 'public')
app.post '/items', (req, res, next) ->
  {storyId} = req.body
  if storyId? then extraParents = [storyId]
  story = mainStory.child {src: 'server', title: "HTTP request #{chalk.green req.url}", extraParents}
  res.json db.getItems {story}
  story.close()
httpServer = http.createServer app
httpServer.listen PORT
mainStory.info 'server', "Listening on port #{chalk.cyan PORT}..."

# Apart from the pre-installed console listener, 
# add remote access to server logs via WebSockets 
# (but ask for credentials)
storyboard.addListener wsServer,
  httpServer: httpServer
  authenticate: ({login, password}) -> true

# Some example logs
mainStory.debug 'server', "Server info (example):"
someInfo = 
  appName: 'Storyboard example'
  upSince: new Date()
  loginRequiredForLogs: true
  nested: configOptions: 
    foo: undefined
    bar: null
    values: [1, 2]
someInfo.nested.configOptions.mainInfo = someInfo
mainStory.tree 'server', someInfo, {level: 'TRACE'}, '  '

# Initialise our database
db = require './db'
db.init()

setInterval -> 
  mainStory.debug 'server', "t: #{chalk.blue new Date().toISOString()}"
, 10000