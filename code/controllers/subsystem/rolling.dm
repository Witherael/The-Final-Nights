SUBSYSTEM_DEF(roll)
	name = "Dice Rolling"
	flags = SS_NO_INIT | SS_NO_FIRE

/**
 * Rolls a number of dice according to Storyteller system rules to find
 * success or number of successes.
 *
 * Rolls a number of 10-sided dice, counting them as a "success" if
 * they land on a number equal to or greater than the difficulty. Dice
 * that land on 1 subtract a success from the total, and the minimum
 * difficulty is 2. The number of successes is returned if numerical
 * is true, or the roll outcome (botch, failure, success) as a defined
 * number if false.
 *
 * Arguments:
 * * dice - number of 10-sided dice to roll.
 * * difficulty - the number that a dice must come up as to count as a success.
 * * numerical - whether the proc returns number of successes or outcome (botch, failure, success)
 * * roll header:
 */

/datum/controller/subsystem/roll/proc/storyteller_roll(dice = 1, difficulty = 6, numerical = FALSE, list/mobs_to_show_output = list())
	var/list/rolled_dice = roll_dice(dice)
	if(!islist(mobs_to_show_output))
		mobs_to_show_output = list(mobs_to_show_output)
	var/output_text = ""
	output_text += span_notice("Rolling [length(rolled_dice)] dice against difficulty [difficulty].")
	var/success_count = count_success(rolled_dice, difficulty, output_text)

	var/output = roll_answer(success_count, numerical, output_text)
	for(var/mob/player_mob as anything in mobs_to_show_output)
		if(player_mob.client.prefs.chat_toggles & CHAT_ROLL_INFO)
			to_chat(player_mob, output_text)
	return output

//Roll each ten sided die, see what numbers we get.
/datum/controller/subsystem/roll/proc/roll_dice(dice)
	var/list/rolled_dice = list()
	for(var/i in 1 to dice)
		rolled_dice += rand(1, 10)
	return rolled_dice

//Count the number of successes.
/datum/controller/subsystem/roll/proc/count_success(list/rolled_dice, difficulty, output_text)
	var/success_count = 0
	for(var/roll as anything in rolled_dice)
		if(roll >= difficulty)
			output_text += span_nicegreen("[roll]")
			success_count++
		else if(roll == 1)
			output_text += span_userdanger(span_boldwarning("[roll]"))
			success_count--
		else
			output_text += span_userdanger("[roll]")
		output_text += ", "
	return success_count

/datum/controller/subsystem/roll/proc/roll_answer(success_count, numerical, output_text)
	if(numerical)
		return success_count
	else
		if(success_count < 0)
			output_text += span_userdanger(span_boldwarning("Botch!"))
			return ROLL_BOTCH
		else if(success_count == 0)
			output_text += span_userdanger("Failure!")
			return ROLL_FAILURE
		else
			output_text += span_nicegreen("Success!")
			return ROLL_SUCCESS
