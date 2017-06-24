#
# Options for cleaning up the system
#
step5_func()
{
	TITLE="Uninstall and system cleanup"

	TEXT[1]="Unbind devices from IGB UIO or VFIO driver"
	FUNC[1]="unbind_devices"

	TEXT[2]="Remove IGB UIO module"
	FUNC[2]="remove_igb_uio_module"

	TEXT[3]="Remove VFIO module"
	FUNC[3]="remove_vfio_module"

	TEXT[4]="Remove KNI module"
	FUNC[4]="remove_kni_module"

	TEXT[5]="Remove hugepage mappings"
	FUNC[5]="clear_huge_pages"
}

STEPS[1]="step1_func"
STEPS[2]="step2_func"
STEPS[3]="step3_func"
STEPS[4]="step4_func"
STEPS[5]="step5_func"

QUIT=0

while [ "$QUIT" == "0" ]; do
	OPTION_NUM=1

	for s in $(seq ${#STEPS[@]}) ; do
		${STEPS[s]}

		echo "----------------------------------------------------------"
		echo " Step $s: ${TITLE}"
		echo "----------------------------------------------------------"

		for i in $(seq ${#TEXT[@]}) ; do
			echo "[$OPTION_NUM] ${TEXT[i]}"
			OPTIONS[$OPTION_NUM]=${FUNC[i]}
			let "OPTION_NUM+=1"
		done

		# Clear TEXT and FUNC arrays before next step
		unset TEXT
		unset FUNC

		echo ""
	done

	echo "[$OPTION_NUM] Exit Script"
	OPTIONS[$OPTION_NUM]="quit"
	echo ""
	echo -n "Option: "
	read our_entry
	echo ""
	${OPTIONS[our_entry]} ${our_entry}

	if [ "$QUIT" == "0" ] ; then
		echo
		echo -n "Press enter to continue ..."; read
	fi

done