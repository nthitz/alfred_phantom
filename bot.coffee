PlugBotAPI = require('plugbotapi');
_ = require('lodash')
creds = {
    email: process.env.EMAIL,
    password: process.env.PASSWORD
}
bot = new PlugBotAPI(creds);
room = 'mashupfm';

welcomeMessages = [
  "welcome to paradise"
]
songLengthLimit = 8
songLengthLimitSeconds = songLengthLimit * 60
enforceSongLength = true
songLengthRelaxing = false
songLengthLimitSkipTimeout = null
songLengthLimitWarnTimeout = null
autoSkipTimeout = null
currentDJName = null
currentDJ = null
enableAutoSkip = false
botadmins = ['3655973']
roomStaff = []
cycleLimits = [5,10]
cycleLimits = [1,2]
enforceAFKAtHowManyDJs = 8
#enforceAFKAtHowManyDJs = 0
afkLimit = 180 * 60 * 1000
#afkLimit = 1000

mehLimit = 5
bootTime = Date.now()
lastUserChats = {}
curVotes = {}

bot.connect(room);

bot.on('roomJoin', () ->
  console.log("Connected!");
  bot.chat welcomeMessages[Math.floor(Math.random() * welcomeMessages.length)]

  ###
  bot.chat('i like turtles')
  bot.getUsers(function(users) {
    console.log("Number of users in the room: " + users.length);
  });
  ###
  bot.getDJ((data) ->
    initEvents()
    if typeof data is 'undefined'
      return
    currentDJ = data
  )
  updateStaff()
);
updateStaff = () ->
  bot.getStaff((data) ->
    roomStaff = data
  )
initEvents = () ->
#// A few sample events
  bot.on('chat', chatHandler);
  bot.on('advance', djAdvanceHandler);
  bot.on('voteUpdate', voteUpdateHandler);
  bot.on('userJoin', userJoinHandler)



chatHandler = (data) ->
    # doing either of these crashes the bot if special chars?/
    #console.log data
    #process.stdout.write(JSON.stringify(data))
    lowercase = data.message.toLowerCase()
    lastUserChats[data.uid] = Date.now()
    fromBotAdmin = isBotAdmin(data.uid)
    fromStaff = isRoomStaff(data.uid)
    if (lowercase.indexOf('bot') isnt -1 or lowercase.indexOf('alfred') isnt -1) and lowercase.indexOf('dance') isnt -1
        bot.woot()
    limitCmd = lowercase.match('(bot|alfred) limit ([0-9]+|off)')
    if limitCmd isnt null
        console.log limitCmd
        param = limitCmd[2]
        if param is '0'
            param = 'off'
        if param is 'off'
            enforceSongLength = false
            bot.chat 'The time limit is off.'
        else
            enforceSongLength = true
            songLengthLimit = param 
            songLengthLimitSeconds = songLengthLimit * 60
            bot.chat 'The time limit is now ' + param + ' minutes.'
    if lowercase.match('(bot|alfred) relax') and fromStaff
        songLengthRelaxing = true
        clearTimeout songLengthLimitSkipTimeout
        clearTimeout songLengthLimitWarnTimeout
        bot.chat 'I\'m calmer than you are.'
    if lowercase.match('(bot|alfred) skip') and fromStaff
        userSkip()

    if lowercase.match('(bot|alfred) autoskip') and fromStaff
        enableAutoSkip = !enableAutoSkip
        bot.chat 'ok, starting next song, autoskip is ' + if enableAutoSkip then 'on' else 'off'

    ###
    if (data.type == 'emote')
        console.log(data.un+data.message)
    else
        console.log(data.un+"> "+data.message)
    ###
djAdvanceHandler = (data) ->
    console.log data
    curVotes = {}
    if typeof data.dj isnt 'undefined'
        currentDJ = data.dj
    else
        currentDJ = null
    clearTimeout(songLengthLimitSkipTimeout)
    clearTimeout songLengthLimitWarnTimeout
    clearTimeout autoSkipTimeout
    bot.getWaitList((waitlist) ->
      if waitlist.length > (enforceAFKAtHowManyDJs - 1)
        enforceAFK(waitlist)
    )
    songLengthRelaxing = false
    if typeof data.media is 'undefined' or data.media is null
        return
    if data.media.duration > songLengthLimitSeconds and enforceSongLength
        skipAt = data.media.duration - songLengthLimitSeconds
        hours = Math.floor(skipAt / (60 * 60))
        if hours is 0
            hours = ''
        else
            hours += ':'
        mins = Math.floor((skipAt % (60 * 60))/ 60)
        if mins < 10 and hours isnt ''
            mins = '0' + mins
        seconds =  Math.floor(skipAt % 60)
        if seconds < 10
            seconds = '0' + seconds
        skipAtStr = hours + mins + ":" + seconds
        bot.chat "@" + currentDJ.username + " Your song is longer than the limit of " + songLengthLimit + " minutes. Please skip when there is " + skipAtStr + ' remaining.'
        songLengthLimitWarnTimeout = setTimeout(warnUserSongLengthSkip, (songLengthLimitSeconds - 15) * 1000)
        songLengthLimitSkipTimeout = setTimeout(userSkip, songLengthLimitSeconds * 1000)

    if enableAutoSkip
        autoSkipTimeout = setTimeout userSkip, (data.media.duration + 3)* 1000
        




voteUpdateHandler = (data) ->
    curVotes[data.user.id] = data.vote
    numMehs = 0
    for userid,vote of curVotes
        if vote is -1
            numMehs++
    if numMehs >= mehLimit
        skipForShittySong()

userJoinHandler = (data) ->
    lastUserChats[data.id] = Date.now()
    updateStaff()
enforceAFK = (waitlist) ->
  time = Date.now()
  minActionTime = time - afkLimit
  bot.getDJ((data) ->
    checkIfCurDJStillAFK(data, minActionTime)
  )
  if waitlist.length > 0
    checkIfOnDeckAFK(waitlist[0],minActionTime)
checkIfCurDJStillAFK = (dj, timeLimit) ->
    if typeof lastUserChats[dj.id] is 'undefined'
        lastUserChats[dj.id] = Date.now()
        return
    lastChat = lastUserChats[dj.id]
    if lastChat is -1
        bot.chat "@"+dj.username + " please stay active to dj"
        bot.moderateRemoveDJ(currentDJ.id)
checkIfOnDeckAFK = (dj, timeLimit) ->
    if typeof lastUserChats[dj.id] is 'undefined'
        return
    lastChat = lastUserChats[dj.id]
    if lastChat < timeLimit
        bot.chat "@" + dj.username + " are you still there? You are on deck! Please chat to ensure you are active!"
        lastUserChats[dj.id] = -1

skipForShittySong = () ->
    bot.chat "@" + currentDJ.username + " your song has been skipped for receiving " + mehLimit + " mehs."
    userSkip()


warnUserSongLengthSkip = () ->
    console.log 'warn'
    if currentDJ is null
        return
    bot.chat "@"+ currentDJ.username + " you have 15 seconds to skip before being escorted"

userSkip = () ->
    if currentDJ is null
        return
    console.log 'skipping someone'    
    bot.moderateForceSkip()
    
isBotAdmin = (userid) ->
    return botadmins.indexOf(userid) isnt -1
isRoomStaff = (userid) ->
  return _.some(roomStaff, (staff) ->
    console.log staff.id + " " +userid
    return staff.id is userid
  )
