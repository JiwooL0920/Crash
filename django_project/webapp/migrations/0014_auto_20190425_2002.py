# Generated by Django 2.1.7 on 2019-04-25 20:02

from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('webapp', '0013_userinfo_points'),
    ]

    operations = [
        migrations.RenameField(
            model_name='userinfo',
            old_name='averagePoints',
            new_name='avgPoints',
        ),
    ]