from django.shortcuts import render
from django.http import HttpResponse, JsonResponse
from django.contrib.auth.models import User
from django.contrib.auth import authenticate, login, logout
import json
from . models import UserInfo
from django.utils import timezone

#1) Signup
def sign_up(request):
	json_req = json.loads(request.body)
	uname = json_req.get('username','')
	passw = json_req.get('password','')
	#Username and Password cannot be empty
	if uname != '' and passw != '':
		try:
			user = User.objects.create_user(username=uname, password=passw)
			userinfo = UserInfo.objects.create(user=user)
			user.save()
			userinfo.save()
			login(request,user)
			return HttpResponse('SignupSuccess')
		except:
			return HttpResponse('UserAlreadyExists')
	else:
		return HttpResponse('SignupFail')

#2) Login
def login_user(request):
        json_req = json.loads(request.body.decode('utf-8'))
#        print("print:" + str(json_req))
        uname = json_req.get('username','')
        passw = json_req.get('password','')
        user = authenticate(request,username=uname,password=passw)
        if user is not None:
                login(request,user)
                return HttpResponse('LoggedIn')
        else:
                return HttpResponse('LoginFailed')

#3) Logout
def logout_user(request):
        logout(request)
        return HttpResponse('LoggedOut')

#3) Post User Info (Receives json body including highscore, points, gamesPlayed, playerTheme, deviceTheme)
def postUserInfo(request):
	#Retrieve userinfo from request
	json_req = json.loads(request.body.decode('utf-8'))
#	print("print:"+str(json_req))
	highscore = json_req.get('highscore',0)
	points = json_req.get('points',0)
	gamesPlayed = json_req.get('gamesPlayed',0)
	playerTheme = json_req.get('playerTheme','1')
	deviceTheme = json_req.get('deviceTheme','1')
	#Get user from session info
	user = request.user
	if user.is_authenticated:
		userinfo = UserInfo.objects.get(user=user)
		if highscore > userinfo.highscore: #update user highscore if the highscore received from post is greater than the highscore on database
			userinfo.highscore = highscore
			userinfo.updatedTime = timezone.now() #Update the datetime of highscore update time
		userinfo.gamesPlayed = gamesPlayed
		userinfo.totalPoints += points
		userinfo.playerTheme = playerTheme
		userinfo.deviceTheme = deviceTheme
		if userinfo.gamesPlayed > 0: #to avoid division by zero error
			userinfo.avgPoints = round((userinfo.totalPoints/userinfo.gamesPlayed),5)
		userinfo.save()
		return HttpResponse("UpdatedUserInfo")
	else:
		return HttpResponse("UserIsNotLogged")

#4) Get User Info (sends json response including highscore, average points, gamesPlayed, playerTheme, deviceTheme)
def getUserInfo(request):
	#Get user from session info
	user = request.user
	if user.is_authenticated:
		userinfo = UserInfo.objects.get(user=user)
		userhighscore = userinfo.highscore
		respDict = {}
		respDict['highscore'] = userinfo.highscore
		respDict['avgPoints'] = userinfo.avgPoints
		respDict['gamesPlayed'] = userinfo.gamesPlayed
		respDict['playerTheme'] = userinfo.playerTheme
		respDict['deviceTheme'] = userinfo.deviceTheme
#		print(str(respDict))
		return JsonResponse(respDict)
	else:
		return HttpResponse("UserIsNotLoggedIn")

#5) Get LeaderBoard (sends json response of the top5 overall highscorer's username and highscore information)
def getLeaderBoard(request):
	top5_UserInfo = UserInfo.objects.order_by('-highscore','updatedTime')[:5] #extracts the userinfo of top 5 highscorers, ordering from highest score to lowest score (if two highscores are the same, then orders by the updated time (whoever achieved that highscore first)
	respDict = {}
	keys = ["firstPlace","secondPlace","thirdPlace","fourthPlace","fifthPlace"]
	#Put into appropriate json format with username and highscore as keys
	for i in range (len(top5_UserInfo)):
		username = top5_UserInfo[i].user.username
		highscore = top5_UserInfo[i].highscore
		respDict[keys[i]] = {"username":username,"highscore":highscore}
	#If there are less than 5 players in the database, append empty username and highscore at the end
	if len(respDict) < 5:
		for i in range (len(respDict),5):
			respDict[keys[i]] = {"username":"---------","highscore":0}
#	print(str(respDict))
	return JsonResponse(respDict)
