express = require('express')
path = require 'path'
spawn = require('child_process').spawn

bot = null

restart = (req, res) ->
  bot.kill()
  # bot = makeBot()

app = express()
app.use(express.static(path.join(__dirname, 'public')))
app.get('/restart',restart)

app.listen(4200)

makeBot = () ->
  bot = spawn('coffee', ['bot.coffee'])

  print = (data) ->
    console.log data.toString()
  bot.stdout.on('data', print)
  bot.stderr.on('data', print)
  bot.on('close', (code) ->
    console.log 'exited with ' + code
    setTimeout(makeBot, 500)
  )
  return bot

bot = makeBot()
