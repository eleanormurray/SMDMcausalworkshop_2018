###########################################################################
# File name: workshop_v2.R
# Programmer: Lucia Petito
# Date: October 2, 2018
# Purpose: Commented code to go along with survival workshop
###########################################################################

# Code Section 0 - Data Setup ---------------------------------------
rm(list=ls())
# Set working directory to your location
setwd('C:/Users/lucia/Dropbox/SMDM.shortcourse/SimulatedData/')
#setwd('/Users/lucia/hsphDropbox/Dropbox/SMDM.shortcourse/SimulatedData/')

# Load the following packages. If they do not exist on your computer,
# this code will automatically install them into your default library. 

# To use restricted cubic splines
if(!require(rms)) { install.packages("rms"); require(rms)}
# To run Cox PH models
if(!require(survival)) { install.packages("survival"); require(survival)}
# To calculate robust estimates of standard errors
if(!require(sandwich)) { install.packages("sandwich"); require(sandwich)}
if(!require(lmtest)) { install.packages("lmtest"); require(lmtest)}
# To plot results
if(!require(ggplot2)) { install.packages("ggplot2"); require(ggplot2)}
# To plot survival curves
if(!require(survminer)) { install.packages("survminer"); require(survminer)}
# To easily change data from long to wide
if(!require(reshape2)) { install.packages("reshape2"); require(reshape2)}



# Code Section 1 - Data Exploration ---------------------------------------

# Load the data from the trial
trial <- read.csv('trial1.csv', header=TRUE)

# Print the names of the available variables
names(trial)

# Look at the first 100 observations of the variables 'simid', 'visit', and 'rand'
View(trial[1:100, c('simID', 'visit', 'rand')])

# Total person-time
pt <- nrow(trial)

# Sample size
n <- length(unique(trial$simID))

# Number of observations at each visit
visitprocess <- table(trial$visit)

# Create 'maxVisit' - total amount of time each individual contributed
trial$maxVisit <- ave(trial$visit, trial$simID, FUN=max)

# The variable death is only '1' at end-of-followup
# Create 'deathOverall' - an indicator of whether an individual died at any 
# point during follow-up
trial$deathOverall <- ave(trial$death, trial$simID, FUN=sum)

# Create 'baseline' - data collected at visit 0
baseline <- trial[trial$visit==0,]

pt
n
visitprocess
with(baseline, table(rand))
with(baseline, table(rand, deathOverall))
with(baseline, round(100*prop.table(table(rand, deathOverall), 1), 1))


# Code Section 2 - Kaplan Meier -------------------------------------------

# Use kaplan meier to nonparametrically estimate survival in each arm
# Note - this requires 1 observation per person of T (maxVisit - end of follow-up) and
# Delta (an indicator of whether death occurred at end of follow-up)
kmfit <- survfit(Surv(maxVisit, deathOverall) ~ rand, data = baseline)
summary(kmfit)

# Plot the output
ggsurvplot(kmfit, 
           data = baseline,
           conf.int=F,
           legend.labs = c("Placebo", "Treated"),
           ylim = c(0.7, 1),
           surv.scale = 'percent',
           xlab = "Number of Visits",
           title = "Kaplan-Meier Curve showing survival in each trial arm",
           risk.table = TRUE,
           break.time.by=2,
           ggtheme = theme_bw())

# Code Section 3 - Conditional Hazard Ratios ------------------------------

# Data processing: create squared time variable [visit2]
trial$visit2 <- trial$visit*trial$visit

# Calculate the unadjusted hazard ratio from a Cox PH model
cox_fit <- coxph(Surv(maxVisit, deathOverall) ~ rand, data = baseline, method='breslow')
summary(cox_fit)

# Calculate the unadjusted hazard ratio from a pooled logistic regression model
plr_fit <- glm(death ~ visit + visit2 + rand, data = trial, family=binomial())
coeftest(plr_fit, vcov=vcovHC(plr_fit, type="HC1")) # To get robust SE estimates
exp(coef(plr_fit)) # to get Hazard Ratios

# Calculate the baseline covariate-adjusted hazard ratio from a Cox PH model
adj_cox_fit <- coxph(Surv(maxVisit, deathOverall) ~ rand + mi_bin + NIHA_b + HiSerChol_b +
                       HiSerTrigly_b + HiHeart_b + CHF_b + 
                       AP_b + IC_b + DIUR_b + AntiHyp_b + 
                       OralHyp_b + CardioM_b + AnyQQS_b + 
                       AnySTDep_b + FVEB_b + VCD_b, 
                     data = baseline, method='breslow')
summary(adj_cox_fit)

# Calculate the baseline covariate-adjusted hazard ratio from a pooled logistic regression model
adj_plr_fit <- glm(death ~ visit + visit2 + rand + mi_bin + NIHA_b + HiSerChol_b +
                     HiSerTrigly_b + HiHeart_b + CHF_b + 
                     AP_b + IC_b + DIUR_b + AntiHyp_b + 
                     OralHyp_b + CardioM_b + AnyQQS_b + 
                     AnySTDep_b + FVEB_b + VCD_b, data = trial, family=binomial())
coeftest(adj_plr_fit, vcov=vcovHC(adj_plr_fit, type="HC1")) # To get robust SE estimates
exp(coef(adj_plr_fit))

# Code Section 4 - Marginal Effects ---------------------------------------

# Step 1. Data processing: interaction terms
# Create interaction terms between visit, visit2, and randomization
trial$randvisit <- trial$rand*trial$visit
trial$randvisit2 <- trial$rand*trial$visit2

# Step 2. Fit a pooled logistic  regression model with interaction terms between 
# rand and visit & visit1 to allow flexible fitting of baseline hazard
adj_plr_ix_fit <- glm(death ~ visit + visit2 + rand + randvisit + randvisit2 + 
                        mi_bin + NIHA_b + HiSerChol_b +
                        HiSerTrigly_b + HiHeart_b + CHF_b + 
                        AP_b + IC_b + DIUR_b + AntiHyp_b + 
                        OralHyp_b + CardioM_b + AnyQQS_b + 
                        AnySTDep_b + FVEB_b + VCD_b, data = trial, family=binomial)
summary(adj_plr_ix_fit)
exp(coef(adj_plr_ix_fit))

# Step 3. Create simulated data where everyone is treated
# Expand baseline so it contains a visit at each time point for every individual
# where the baseline information has been carried forward at each time
treated <- baseline[rep(1:n,each=15),]
treated$visit <- rep(0:14, times=n) # This recreates the time variable
treated$visit2 <- treated$visit * treated$visit # This recreates the time squared variable

# Set the treatment assignment to '1' for each individual and
# recreate the splined visit term and the interaction terms
treated$rand <- 1
treated$randvisit <- treated$rand*treated$visit
treated$randvisit2 <- treated$rand*treated$visit2

# 'predict' returns predicted "density" of survival at each time
# conditional on covariates
# Turn these into predicted survival density by subtracting from 1
treated$p <- 1 - predict(adj_plr_ix_fit, newdata=treated, type='response')
# We calculate survival by taking the cumulative product by individual
treated$s <- ave(treated$p, treated$simID, FUN=cumprod)

# Step 4. Create simulated data where everyone receives placebo
# When simulating data in the placebo arm, only difference from treated is 
# in the randomization assignment, and resulting interaction terms
placebo <- treated
placebo$rand <- 0
placebo$randvisit <- placebo$rand*placebo$visit
placebo$randvisit2 <- placebo$rand*placebo$visit2

# 'predict' returns predicted probability density at each time
# conditional on covariates
# We turn them into predicted survival density by subtracting from 1
placebo$p <- 1 - predict(adj_plr_ix_fit, newdata=placebo, type='response')
# We calculate survival by taking the cumulative product by individual
placebo$s <- ave(placebo$p, placebo$simID, FUN=cumprod)

# Step 5. Calculate standardized survival at each time
# Create concatenated dataset, only keep s, rand, and visit
both <- rbind(treated, placebo)
both <- both[,c('s', 'rand', 'visit')]

# Calculate the mean survival at each visit within each treatment arm
results <- aggregate(s ~ visit + rand, FUN=mean, data=both)

# Edit results data frame to reflect that our estimates are for the END of the interval [t, t+1)
# Add a row for each of Placebo and Treated where survival at time 0 is 1.
results$visit <- results$visit + 1
results <- rbind(c(0, 0, 1), c(0, 1, 1), results)

# Add a variable that treats randomization as a factor
results$randf <- factor(results$rand, labels = c("Placebo", "Treated"))

# Step 6. Plot the results
ggplot(results, aes(x=visit, y=s))+
  geom_line(aes(colour=randf)) +
  geom_point(aes(colour=randf))+
  xlab("Number of Visits") +
  scale_x_continuous(limits = c(0, 15), breaks=seq(0,15,2)) +
  ylab("Probability of Survival") +
  ggtitle("Survival Curves Standardized for Baseline Covariate Distribution") +
  labs(colour="Treatment Arm") +
  theme_bw() +
  theme(legend.position="bottom") 

# Step 7. Calculate risk difference and hazard ratio at 14 weeks
# Transpose the data so survival in each treatment arm is separate
wideres <- dcast(results, visit ~ randf, value.var = 's')
head(wideres)

# Create summary statistics
wideres$RD <- wideres$Treated - wideres$Placebo
wideres$logRatio <- log(wideres$Treated) / log(wideres$Placebo)
wideres$logRatio[1] <- NA
wideres$cHR <- sapply(0:15, FUN=function(x){mean(wideres$logRatio[wideres$visit <= x], na.rm=T)})

# Print all wide results to fill in table
round(wideres, 3)

# Overall Hazard Ratio
wideres$cHR[wideres$visit==15]
# Risk difference at end of 14 visits
wideres$RD[wideres$visit==15]


# Code Section 5 - Data cleaning for IPW ----------------------------------

# Remove all objects from the R environment EXCEPT the cleaned trial dataframe
rm(list=setdiff(ls(), "trial"))

# Create a placebo dataset that only contains individuals with placebo
placebo <- trial[trial$rand==0,]

# Check to see how many individuals in your dataset
n <- length(unique(placebo$simID))
n

# Number of individuals who adhered versus did not adhere at visit 0
table(placebo$adhr_b[placebo$visit==0])

# View first 100 observations of simID, visit, adhr_b, and adhr, and 
# simID, visit, adhr_b, and adhr where adhr_b==1 to understand these variables better
View(placebo[1:50,c("simID", 'visit', 'adhr_b', 'adhr')])
View(placebo[placebo$adhr_b==1,c("simID", 'visit', 'adhr_b', 'adhr')])

# Create interaction terms between exposure (adhr_b) and visit, visit2
placebo$adhr0visit <- placebo$adhr_b*placebo$visit
placebo$adhr0visit2 <- placebo$adhr_b*placebo$visit2

# Create censoring variable - indicate when individual deviates from baseline
placebo$cens_new <- as.numeric(placebo$adhr != placebo$adhr_b) 

# Need to recreate maxVisit and deathOverall - slightly more complicated now
placebo$maxVisit <- unlist(by(placebo, placebo$simID, FUN=function(subsi){
  # subsi is the subset of the data for individual i
  if(sum(subsi$cens_new==0)){# If there is perfect adherence at all times to baseline adherence,
    m <- max(subsi$visit) # Just use maximum observed visit
  } else { # If at some point individual i deviates from their baseline adherence,
    # Use the first visit where they deviated
    m <-min(subsi$visit[subsi$cens_new==1])
  }
  rep(m, nrow(subsi)) # Add this column to subsi
}) )
placebo$deathOverall <- unlist(by(placebo, placebo$simID, FUN=function(subsi){
  # subsi is the subset of the data for individual i
  # m indicates whether death happened while individual i was still contributing person-time
  m <- as.numeric(sum(subsi$death[subsi$visit <= subsi$maxVisit]) > 0)
  rep(m, nrow(subsi)) # Add this column to subsi
}) )

# Create baseline data
baseline <- placebo[placebo$visit==0,]

# Check kaplan-meier fit in each arm
kmfit <- survfit(Surv(maxVisit, deathOverall) ~ adhr_b, data = baseline)
summary(kmfit)

# Plot the output
ggsurvplot(kmfit, 
           data = baseline,
           conf.int=F,
           ylim = c(0.7, 1),
           surv.scale = 'percent',
           legend.labs = c("Nonadherers", "Adherers"),
           xlab = "Number of Visits",
           title = "Kaplan-Meier Curve showing survival by adherence",
           risk.table = TRUE,
           break.time.by=2,
           ggtheme = theme_bw())

# Code Section 6 - Weight Creation ----------------------------------------

# Numerator: Pr(adhr(t)=1|adhr_b, Baseline covariates)
# This model is created in data EXCLUDING the baseline visit

nFit <- glm(adhr ~ visit + visit2 + adhr_b + 
              mi_bin + NIHA_b + HiSerChol_b +
              HiSerTrigly_b + HiHeart_b + CHF_b + 
              AP_b + IC_b + DIUR_b + AntiHyp_b + 
              OralHyp_b + CardioM_b + AnyQQS_b + 
              AnySTDep_b + FVEB_b + VCD_b,
            data=placebo[placebo$visit > 0,],
            family=binomial())

# Create predicted probability at each time point 
# (Pr(adhr(t) = 1 | adhr_b, baseline))
placebo$pnum <- predict(nFit, newdata=placebo, type='response')

# Denominator: Pr(adhr(t)=1|adhr_b, Baseline covariates, Time-varying covariates)
dFit <- glm(adhr ~ visit + visit2 + adhr_b + 
              mi_bin + NIHA_b + HiSerChol_b +
              HiSerTrigly_b + HiHeart_b + CHF_b + 
              AP_b + IC_b + DIUR_b + AntiHyp_b + 
              OralHyp_b + CardioM_b + AnyQQS_b + 
              AnySTDep_b + FVEB_b + VCD_b +
              NIHA + HiSerChol +
              HiSerTrigly + HiHeart + CHF +
              AP + IC + DIUR + AntiHyp +
              OralHyp + CardioM + AnyQQS +
              AnySTDep + FVEB + VCD,
            data=placebo[placebo$visit > 0,],
            family=binomial())
# Create predicted probability at each time point 
# (Pr(adhr(t) = 1 | adhr_b, baseline, time-varying covariates))
placebo$pdenom <-  predict(dFit, newdata=placebo, type='response')

# Sort placebo by simID and visit
placebo <- placebo[order(placebo$simID, placebo$visit),]

# Contribution from adhr(t) = 0 is 1 - p
# Contribution from adhr(t) = 1 is p
placebo$numCont <- with(placebo, adhr*pnum + (1-adhr)*(1-pnum))
placebo$denCont <- with(placebo, adhr*pdenom + (1-adhr)*(1-pdenom))

# Set contribution at baseline visit to 1
placebo$numCont[placebo$visit==0] <- 1; placebo$denCont[placebo$visit==0] <- 1

# Numerator
placebo$k1_0 <- with(placebo, ave(numCont, simID, FUN=cumprod))
# Denominator
placebo$k1_w <- with(placebo, ave(denCont, simID, FUN=cumprod))

# Create both stabilized and unstabilized weights
placebo$stabw <- with(placebo, k1_0 / k1_w)
placebo$unstabw <- with(placebo, 1 / k1_w)

# Check the weights
# Can do this with built-in functions
summary(placebo$stabw); quantile(placebo$stabw, p=c(0.01, 0.10, 0.25, 0.5, 0.75, 0.9, 0.95, 0.99, 0.995))
summary(placebo$unstabw); quantile(placebo$unstabw, p=c(0.01, 0.10, 0.25, 0.5, 0.75, 0.9, 0.95, 0.99, 0.995))

# Or write something for yourself
wt_check_fxn <- function(x, d){
  # x - weight vector
  # d - number of digits to round to
  round(data.frame(N = length(x),
                   Missing = sum(is.na(x)),
                   Distinct = length(unique(x)),
                   Mean = mean(x, na.rm=T),
                   SD = sd(x, na.rm=T),
                   Min = min(x, na.rm=T),
                   Q.01 = quantile(x, p=0.01),
                   Q.25 = quantile(x, p=0.25),
                   Q.50 = quantile(x, p=0.5),
                   Q.75 = quantile(x, p=0.75),
                   Q.90 = quantile(x, p=0.9),
                   Q.95 = quantile(x, p=0.95),
                   Q.99 = quantile(x, p=0.99),
                   Q.995 = quantile(x, p=0.995),
                   Max = max(x, na.rm=T), digits=d)
        )
}
wt_check_fxn(placebo$stabw, 3)
wt_check_fxn(placebo$unstabw, 3)

# To prevent high weights from too much influence, truncate
threshold <- quantile(placebo$stabw, 0.99) # Here we chose 99th %tile
placebo$stabw_t <- placebo$stabw
placebo$stabw_t[placebo$stabw > threshold] <- threshold

wt_check_fxn(placebo$stabw_t, 3)

# Code Section 7 - Weighted Conditional Hazard Ratios ---------------------

# Truncated stabilized weights
plrFit_SWT <- glm(death ~ visit + visit2 + adhr_b + 
                    mi_bin + NIHA_b + HiSerChol_b +
                    HiSerTrigly_b + HiHeart_b + CHF_b + 
                    AP_b + IC_b + DIUR_b + AntiHyp_b + 
                    OralHyp_b + CardioM_b + AnyQQS_b + 
                    AnySTDep_b + FVEB_b + VCD_b,
                  data=placebo[placebo$visit <= placebo$maxVisit,],
                  weights = stabw_t,
                  family=quasibinomial())
coeftest(plrFit_SWT, vcov=vcovHC(plrFit_SWT, type="HC1")) # To get robust SE estimates
exp(coef(plrFit_SWT)) # to get Hazard Ratios

# Try changing "weights = stabw_t, " to 
# "weights = stabw_t, " for stabilized fit
# "weights = unstabw, " for unstabilized fit

# Code Section 8 - Weighted Survival Curves -------------------------------

# Step 1. Estimate weighted outcome regression with interactions
plrixFit_USW <- glm(death ~ visit + visit2 + adhr_b + 
                      adhr0visit + adhr0visit2 +
                      mi_bin + NIHA_b + HiSerChol_b +
                      HiSerTrigly_b + HiHeart_b + CHF_b + 
                      AP_b + IC_b + DIUR_b + AntiHyp_b + 
                      OralHyp_b + CardioM_b + AnyQQS_b + 
                      AnySTDep_b + FVEB_b + VCD_b,
                    data=placebo[placebo$visit <= placebo$maxVisit,],
                    weights = stabw_t,
                    family=quasibinomial())

summary(plrixFit_USW)
exp(coef(plrixFit_USW))

# Step 1a. Create dataset with just baseline values 
baseline <- placebo[placebo$visit==0,]

# Step 2. Create simulated data where everyone adheres and doesn't adhere
adherers <- baseline[rep(1:n,each=15),]
adherers$visit <- rep(0:14, times=n) # Recreates the time variable
adherers$visit2 <- adherers$visit * adherers$visit
adherers$adhr_b <- 1
adherers$adhr0visit <- adherers$adhr_b*adherers$visit
adherers$adhr0visit2 <- adherers$adhr_b*adherers$visit2
adherers$p <- 1 - predict(plrixFit_USW, newdata=adherers, type='response')
adherers$s <- ave(adherers$p, adherers$simID, FUN=cumprod)

# Nonadherers
nonadherers <- adherers
nonadherers$adhr_b <- 0
nonadherers$adhr0visit <- nonadherers$adhr_b*nonadherers$visit
nonadherers$adhr0visit2 <- nonadherers$adhr_b*nonadherers$visit2
nonadherers$p <- 1 - predict(plrixFit_USW, newdata=nonadherers, type='response')
nonadherers$s <- ave(nonadherers$p, nonadherers$simID, FUN=cumprod)

# Step 3. Calculate standardized survival at each time
# Create concatenated dataset, only keep s, adhr_b, and visit
both <- rbind(adherers, nonadherers)
both <- both[,c('s', 'adhr_b', 'visit')]

# Calculate the mean survival at each visit within each adherer group
results <- aggregate(s ~ visit + adhr_b, FUN=mean, data=both)

# Edit results data frame to reflect that our estimates are for the END of the interval [t, t+1)
# Add a row for each of Placebo and Treated where survival at time 0 is 1.
results$visit <- results$visit + 1
results <- rbind(c(0, 0, 1), c(0, 1, 1), results)

# Add a variable that treats randomization as a factor
results$adhrf <- factor(results$adhr_b, labels = c("Nonadherers", "Adherers"))

# Plot the results
ggplot(results, aes(x=visit, y=s)) + 
  geom_line(aes(colour=adhrf)) +
  geom_point(aes(colour=adhrf))+
  xlab("Number of Visits") +
  scale_x_continuous(limits = c(0, 15), breaks=seq(0,15,2)) +
  ylab("Probability of Survival") +
  ggtitle("Survival Curves Standardized for Baseline Covariate Distribution \nand weighted for time-varying confounders") +
  labs(colour="Adherer Group") +
  theme_bw() +
  theme(legend.position="bottom") 

# Step 4. Calculate risk difference and hazard ratio at 14 weeks (EOF)
# Transpose the data so survival in each treatment arm is separate
wideres <- dcast(results, visit ~ adhrf, value.var = 's')
head(wideres)
wideres$RD <- wideres$Adherers - wideres$Nonadherers
wideres$logRatio <- log(wideres$Adherers) / log(wideres$Nonadherers)
wideres$logRatio[1] <- NA
wideres$cHR <- sapply(0:15, FUN=function(x){mean(wideres$logRatio[wideres$visit <= x], na.rm=T)})
wideres

# Overall Hazard Ratio
wideres$cHR[wideres$visit==15]
# Risk difference at 14 visits
wideres$RD[wideres$visit==15]
