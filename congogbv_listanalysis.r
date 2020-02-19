library(list)
library(readstata13)
library(pastecs)
library(fastDummies)

dta <- read.dta13("C:/Users/Koen/Dropbox (Personal)/PhD/Papers/CongoGBV/Data/clean/analysis.dta") 

reg <- ictreg(numballs ~ terrfe_2 + terrfe_3 + terrfe_4 + husbmoreland,data=dta,treat="ball5")
summary(reg)


round(stat.desc(dta[,c("numballs","terrfe_2","terrfe_3","terrfe_4","husbmoreland")]),2)

dta_complete <- na.omit(dta[,c("numballs","ball5","terrfe_2","terrfe_3","terrfe_4","husbmoreland")])
round(stat.desc(dta_complete[,c("numballs","terrfe_2","terrfe_3","terrfe_4","husbmoreland")]),2)


reg <- ictreg(numballs ~ terrfe_2 + terrfe_3  + terrfe_4 + husbmoreland ,data=dta_complete,treat="ball5")


dta$villid2 <- as.factor(dta[,"vill_id"])

reg <- ictreg(numballs ~ husbmoreland ,data=dta,treat="ball5")
round(stat.desc(dta[,c("vill_id","numballs","terrfe_2","terrfe_3","terrfe_4","husbmoreland")]),2)
tabulate(dta$villid2)



reg <- ictreg(numballs ~ factor(vill_id) + husbmoreland ,data=dta,treat="ball5")

dta[1:10,grepl("^terrfe_", names(dta))] 


analysis <- dta[c("numballs","ball5","vill_id","husbmoreland")]

analysis <- fastDummies::dummy_cols(analysis, select_columns = "vill_id")

analysis$vill_id <-NULL

reg <- ictreg(numballs ~ . -ball5 ,data=analysis,treat="ball5")

