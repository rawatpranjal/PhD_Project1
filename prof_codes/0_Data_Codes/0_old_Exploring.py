#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Sun Apr 24 08:37:45 2022

@author: albertorossi
"""
for v in dir(): del globals()[v]
import pandas as pd
import matplotlib.pyplot as plt
import os

os.chdir("/Users/albertorossi/Dropbox/Gtown/Flowe/0_Data_Codes/0_Working_Data")

data=pd.read_csv("Transactions_for_analysis.csv",
                 sep=",", on_bad_lines="skip")


data=data[['userId', 'amount', 'direction', 
           'carbonEmissionInGrams', 'isCompensated']]

summ_data_compensation=data.groupby(by=["userId","isCompensated"])[["amount","carbonEmissionInGrams"]].sum()        
summ_data_compensation["ratio"]=summ_data_compensation["carbonEmissionInGrams"]/summ_data_compensation["amount"]


plt.hist(summ_data_compensation["ratio"], bins = 100)
plt.show()


#%%
summ_data=data.groupby(by=["userId",])[["amount","carbonEmissionInGrams"]].sum()        
summ_data["ratio"]=summ_data["carbonEmissionInGrams"]/summ_data["amount"]
plt.hist(summ_data["ratio"], bins = 100)
plt.show()
print(summ_data["ratio"].mean())