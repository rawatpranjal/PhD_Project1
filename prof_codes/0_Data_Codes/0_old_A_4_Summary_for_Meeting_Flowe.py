#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Wed Apr 27 17:43:30 2022

@author: albertorossi
"""
import sys
sys.modules[__name__].__dict__.clear()

import os
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns


os.chdir("/Users/albertorossi/Dropbox/Gtown/Flowe/0_Data_Codes/")

#%% USER SIGN-INS (Tables)


df = pd.read_stata ('./0_Working_Data/UserSignedIn.dta')
df=df[['userId', 'date']].sort_values(by=['userId', 'date'])

# User-time results        
df['ones']=1
N_logins_per_user_per_day=df.groupby(by=['userId','date']).count()        

# User results    
user_res = df[['userId','ones']].groupby(by=['userId']).count()
user_res.columns = user_res.columns.str.replace('ones', 'logins_per_user')
    
user_res['avg_N_logins_per_user_per_day']=  N_logins_per_user_per_day\
    .groupby(by=['userId']).mean()   

user_res['span'] = (df.groupby(['userId'])['date'].max()-\
    df.groupby(['userId'])['date'].min()).dt.days+1
user_res['frac_day_logins'] =user_res['logins_per_user']/user_res['span']

user_res['N_day'] =df.drop_duplicates().groupby('userId').count()['ones']

# days between logins
temp=df.drop_duplicates().sort_values(by=['userId','date']) 
temp['diff']=temp.groupby(['userId'])['date'].diff(periods=1).dt.days         
user_res['N_days_between_logins']=temp.groupby(by=['userId'])['diff'].mean()
del temp

summary_stats_user_level=user_res.describe().transpose()
summary_stats_user_level.to_csv('../0_Results/python_Summary_Logins.csv')


#%% USER SIGN-INS (FIGURES)

# first-last day of login
N_first_users = df.groupby(['userId'])['date'].min().reset_index().\
    groupby(['date']).count().reset_index()
N_last_users= df.groupby(['userId'])['date'].max().reset_index().\
    groupby(['date']).count().reset_index()
        
to_plot = pd.merge(N_first_users, N_last_users, on='date', how="outer").fillna(0)

to_plot.rename(columns = {'userId_x':'N_first_users', \
                          'userId_y':'N_last_users'}, inplace = True)
    
    
to_plot=to_plot.set_index("date").sort_values(by="date")
 
plt.plot(to_plot['N_first_users'],label='Primo Login')
plt.plot(to_plot['N_last_users'],label= 'Ultimo Login')
plt.xticks(rotation=45)
plt.legend(title='Tipo di Login')
plt.savefig('../0_Results/Python_Login_primo_ultimo.png', dpi=1000)    
plt.show() 
    
#%% USER SIGN-INS (FIGURES)
    
# first-last day of login
# day of the week patterns    
temp=df.drop_duplicates().sort_values(by=['userId','date']) 
tot_daily_logins_across_users=temp.groupby(['date']).count().reset_index()

del tot_daily_logins_across_users['userId']
tot_daily_logins_across_users.rename(columns = {'ones':'tot_daily_users'}, \
                                     inplace = True)
tot_daily_logins_across_users['day_of_week'] = \
    tot_daily_logins_across_users['date'].dt.day_name()  
    
del tot_daily_logins_across_users['date']    
#%%
sns.boxplot(x="day_of_week", y="tot_daily_users", 
                 data=tot_daily_logins_across_users, showfliers = False,
                 order=['Sunday','Monday','Tuesday','Wednesday','Thursday', 
                        'Friday','Saturday'])
plt.xticks(rotation=45)
plt.savefig('../0_Results/Python_day_of_the_week.png', dpi=1000)  
   
    
del [df, N_first_users] 
del [N_last_users, N_logins_per_user_per_day]

del [summary_stats_user_level, temp] 
del [to_plot, tot_daily_logins_across_users]
del [user_res]
#%%
df = pd.read_stata ('./0_Working_Data/UserDataValidated.dta')
provinces=df.groupby(['releaseProvince'])["id"].count() 


    
    
    
