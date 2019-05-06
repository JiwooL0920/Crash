from django.db import models
from django.contrib.auth.models import User
from django.utils.timezone import now

# Create your models here

class UserInfoManager(models.Manager):
	def create_user_info(self, username, password, highscore, playerTheme, deviceTheme):
		user = User.objects.create_user(username=username, password=password)
		userinfo = self.create(user=user)
		return userinfo

class UserInfo(models.Model):
	user = models.OneToOneField(User,on_delete=models.CASCADE,primary_key=True)
	highscore = models.IntegerField(default=0)
	updatedTime = models.DateTimeField(default=now,blank=True)
	playerTheme = models.CharField(max_length=10,default='1')
	deviceTheme = models.CharField(max_length=10,default='1')
	gamesPlayed = models.IntegerField(default=0)
	points = models.IntegerField(default=0)
	totalPoints = models.IntegerField(default=0)
	avgPoints = models.FloatField(default=0.0)
	objects = UserInfoManager()


