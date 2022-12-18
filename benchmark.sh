#!/bin/bash

#make
#pwd

diffList=( 'alethea_vot_ShHh_RF' 'chaum_anonymity' 'rfid-feldhofer')

cd files_to_benchmark

for dir in $(ls .)
do
	cd $dir
	if [ ! -d res_$dir ]
	then
	    mkdir res_$dir
	fi
	echo -----------$dir---------
	for file in $(ls .)
	do
		filename=${file%%.*}
		diff=""
		echo $filename
		if [ $filename == "SP5_Anonymity_CERTIFY_ObsEquiv_BSN" ] || [ $filename == "SP5_Anonymity_CERTIFY_ObsEquiv_noBSN" ] || [ $filename == "SP5_Anonymity_QUOTE_ObsEquiv_BSN" ] || [ $filename == "SP5_Anonymity_QUOTE_ObsEquiv_noBSN" ] || [ $filename == "SP5_Anonymity_SIGN_ObsEquiv_BSN" ] || [ $filename == "SP5_Anonymity_SIGN_ObsEquiv_noBSN" ] || [ $filename == "SP6_UserControlledUnlinkability_CERTIFY_ObsEquiv_BSN" ] || [ $filename == "SP6_UserControlledUnlinkability_CERTIFY_ObsEquiv_noBSN" ]
		then 
			diff="--diff"
		fi
		if [ $filename == "SP6_UserControlledUnlinkability_QUOTE_ObsEquiv_BSN" ] || [ $filename == "SP6_UserControlledUnlinkability_QUOTE_ObsEquiv_noBSN" ] || [ $filename == "SP6_UserControlledUnlinkability_SIGN_ObsEquiv_BSN" ] || [ $filename == "SP6_UserControlledUnlinkability_SIGN_ObsEquiv_noBSN" ] || [ $filename == "5G_AKA_passive_privacy_game" ] || [ $filename == "5G_AKA_priv" ] || [ $filename == "5G_AKA_simplified_privacy_active" ] || [ $filename == "alethea_votingphase_Privacy" ]
		then 
			diff="--diff"
		fi
		if [ $filename == "alethea_votingphase_RF" ] || [ $filename == "mixvote_ShHh_RF_reuseAsRestriction" ] || [ $filename == "mixvote_ShHh_RF" ] || [ $filename == "aletheaD_vot_ShHh_RF" ] || [ $filename == "alethea_vot_ShHh_RF" ] || [ $filename == "chaum_anonymity" ] || [ $filename == "rfid-feldhofer" ]
		then 
			diff="--diff"
		fi
		#{ time tamarin-prover --prove $file +RTS -N10 -RTS --output=./res_$dir"/"$filename"recap.spthy" > ./res_$dir"/"$filename"_total.spthy" 2>&1 ; } 2>> ./res_$dir"/"$filename"_time.spthy"
		timeout 24h time tamarin-prover --prove $file $diff +RTS -N10 -RTS --output=./res_$dir"/"$filename"recap.spthy" > ./res_$dir"/"$filename"_total.spthy" 2>&1 ; 2>> ./res_$dir"/"$filename"_time.spthy"
	done
	cd ..
done

cd ..