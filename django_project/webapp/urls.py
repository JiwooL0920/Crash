from django.urls import path
from . import views

urlpatterns = [
    path('signup/', views.sign_up, name='webapp-sign_up'),
    path('loginuser/', views.login_user, name='webapp-login_user'),
    path('logoutuser/',views.logout_user, name='webapp-logout_user'),
    path('postuserinfo/', views.postUserInfo, name='webapp-postUserInfo'),
    path('getuserinfo/', views.getUserInfo, name='webapp-getUserInfo'),
    path('getleaderboard/', views.getLeaderBoard, name='webapp-getLeaderBoard'),
]
