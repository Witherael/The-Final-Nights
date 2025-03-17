/datum/emote
	var/key = "" //What calls the emote
	var/key_third_person = "" //This will also call the emote
	var/name = "" /// Needed for more user-friendly emote names, so emotes with keys like "aflap" will show as "flap angry". Defaulted to key.
	var/message = "" //Message displayed when emote is used
	var/message_mime = "" //Message displayed if the user is a mime
	var/message_alien = "" //Message displayed if the user is a grown alien
	var/message_larva = "" //Message displayed if the user is an alien larva
	var/message_robot = "" //Message displayed if the user is a robot
	var/message_AI = "" //Message displayed if the user is an AI
	var/message_monkey = "" //Message displayed if the user is a monkey
	var/message_simple = "" //Message to display if the user is a simple_animal
	var/message_param = "" //Message to display if a param was given
	var/emote_type = EMOTE_VISIBLE //Whether the emote is visible or audible
	/// Checks if the mob can use its hands before performing the emote.
	var/hands_use_check = FALSE
	var/muzzle_ignore = FALSE //Will only work if the emote is EMOTE_AUDIBLE
	var/list/mob_type_allowed_typecache = /mob //Types that are allowed to use that emote
	var/list/mob_type_blacklist_typecache //Types that are NOT allowed to use that emote
	var/list/mob_type_ignore_stat_typecache
	var/stat_allowed = CONSCIOUS
	var/sound //Sound to play when emote is called
	var/vary = FALSE	//used for the honk borg emote
	var/cooldown = 0.8 SECONDS
	///How often we can do this audio cooldown
	var/audio_cooldown = 2 SECONDS

/datum/emote/New()
	if (ispath(mob_type_allowed_typecache))
		switch (mob_type_allowed_typecache)
			if (/mob)
				mob_type_allowed_typecache = GLOB.typecache_mob
			if (/mob/living)
				mob_type_allowed_typecache = GLOB.typecache_living
			else
				mob_type_allowed_typecache = typecacheof(mob_type_allowed_typecache)
	else
		mob_type_allowed_typecache = typecacheof(mob_type_allowed_typecache)
	mob_type_blacklist_typecache = typecacheof(mob_type_blacklist_typecache)
	mob_type_ignore_stat_typecache = typecacheof(mob_type_ignore_stat_typecache)

	if(!name)
		name = key

/**
 * Handles the modifications and execution of emotes.
 *
 * Arguments:
 * * user - Person that is trying to send the emote.
 * * params - Parameters added after the emote.
 * * type_override - Override to the current emote_type.
 * * intentional - Bool that says whether the emote was forced (FALSE) or not (TRUE).
 *
 */
/datum/emote/proc/run_emote(mob/user, params, type_override, intentional = FALSE)
	var/msg = select_message_type(user, message, intentional)
	if(params && message_param)
		msg = select_param(user, params)

	msg = replace_pronoun(user, msg)
	if(!msg)
		return

	user.log_message(msg, LOG_EMOTE)

	var/tmp_sound = get_sound(user)
	if(tmp_sound)
		if(!TIMER_COOLDOWN_CHECK(user, COOLDOWN_MOB_AUDIO))
			TIMER_COOLDOWN_START(user, type, audio_cooldown)
			S_TIMER_COOLDOWN_START(user, COOLDOWN_MOB_AUDIO, 10 SECONDS)
			playsound(user, tmp_sound, 50, vary)

	var/is_important = emote_type & EMOTE_IMPORTANT
	var/is_visual = emote_type & EMOTE_VISIBLE
	var/is_audible = emote_type & EMOTE_AUDIBLE

	// Emote doesn't get printed to chat, runechat only
	if(emote_type & EMOTE_RUNECHAT)
		for(var/mob/viewer as anything in viewers(user))
			if(isnull(viewer.client))
				continue
			if(!is_important && viewer != user && (!is_visual || !is_audible))
				if(is_audible && !viewer.can_hear())
					continue
				if(is_visual && viewer.is_blind())
					continue
			if(user.runechat_prefs_check(viewer, EMOTE_MESSAGE))
				viewer.create_chat_message(
					speaker = user,
					raw_message = msg,
					runechat_flags = EMOTE_MESSAGE,
				)
			else if(is_important)
				to_chat(viewer, span_emote("<b>[user]</b> [msg]"))
			else if(is_audible && is_visual)
				viewer.show_message(
					span_emote("<b>[user]</b> [msg]"), MSG_AUDIBLE,
					span_emote("You see how <b>[user]</b> [msg]"), MSG_VISUAL,
				)
			else if(is_audible)
				viewer.show_message(span_emote("<b>[user]</b> [msg]"), MSG_AUDIBLE)
			else if(is_visual)
				viewer.show_message(span_emote("<b>[user]</b> [msg]"), MSG_VISUAL)
		return // Early exit so no dchat message

	// The emote has some important information, and should always be shown to the user
	else if(is_important)
		for(var/mob/viewer as anything in viewers(user))
			to_chat(viewer, span_emote("<b>[user]</b> [msg]"))
			if(user.runechat_prefs_check(viewer, EMOTE_MESSAGE))
				viewer.create_chat_message(
					speaker = user,
					raw_message = msg,
					runechat_flags = EMOTE_MESSAGE,
				)
	// Emotes has both an audible and visible component
	// Prioritize audible, and provide a visible message if the user is deaf
	else if(is_visual && is_audible)
		user.audible_message(
			message = msg,
			deaf_message = span_emote("You see how <b>[user]</b> [msg]"),
			self_message = msg,
			audible_message_flags = EMOTE_MESSAGE|ALWAYS_SHOW_SELF_MESSAGE,
		)
	// Emote is entirely audible, no visible component
	else if(is_audible)
		user.audible_message(
			message = msg,
			self_message = msg,
			audible_message_flags = EMOTE_MESSAGE,
		)
	// Emote is entirely visible, no audible component
	else if(is_visual)
		user.visible_message(
			message = msg,
			self_message = msg,
			visible_message_flags = EMOTE_MESSAGE|ALWAYS_SHOW_SELF_MESSAGE,
		)
	else
		CRASH("Emote [type] has no valid emote type set!")

	if(!isnull(user.client))
		var/dchatmsg = "<b>[user]</b> [msg]"
		for(var/mob/ghost as anything in GLOB.dead_mob_list - viewers(get_turf(user)))
			if(isnull(ghost.client) || isnewplayer(ghost))
				continue
			if(!(ghost.client.prefs.chat_toggles & CHAT_GHOSTSIGHT))
				continue
			to_chat(ghost, span_emote("[dchatmsg]"))
	return

/// For handling emote cooldown, return true to allow the emote to happen
/datum/emote/proc/check_cooldown(mob/user, intentional)
	if(!intentional)
		return TRUE
	if(user.emotes_used && user.emotes_used[src] + cooldown > world.time)
		return FALSE
	if(!user.emotes_used)
		user.emotes_used = list()
	user.emotes_used[src] = world.time
	return TRUE

/datum/emote/proc/get_sound(mob/living/user)
	return sound //by default just return this var.

/datum/emote/proc/replace_pronoun(mob/user, message)
	if(findtext(message, "their"))
		message = replacetext(message, "their", user.p_their())
	if(findtext(message, "them"))
		message = replacetext(message, "them", user.p_them())
	if(findtext(message, "%s"))
		message = replacetext(message, "%s", user.p_s())
	return message

/datum/emote/proc/select_message_type(mob/user, msg, intentional)
	// Basically, we don't care that the others can use datum variables, because they're never going to change.
	. = msg
	if(!isliving(user))
		return .
	if(!muzzle_ignore && user.is_muzzled() && emote_type == EMOTE_AUDIBLE)
		return "makes a [pick("strong ", "weak ", "")]noise."
	if(user.mind && user.mind.miming && message_mime)
		. = message_mime
	if(isalienadult(user) && message_alien)
		. = message_alien
	else if(islarva(user) && message_larva)
		. = message_larva
	else if(iscyborg(user) && message_robot)
		. = message_robot
	else if(isAI(user) && message_AI)
		. = message_AI
	else if(ismonkey(user) && message_monkey)
		. = message_monkey
	else if(isanimal(user) && message_simple)
		. = message_simple

	return .

/datum/emote/proc/select_param(mob/user, params)
	return replacetext(message_param, "%t", params)

/datum/emote/proc/can_run_emote(mob/user, status_check = TRUE, intentional = FALSE, params)
	if(!is_type_in_typecache(user, mob_type_allowed_typecache))
		return FALSE
	if(is_type_in_typecache(user, mob_type_blacklist_typecache))
		return FALSE
	if(status_check && !is_type_in_typecache(user, mob_type_ignore_stat_typecache))
		if(user.stat > stat_allowed)
			if(!intentional)
				return FALSE
			switch(user.stat)
				if(SOFT_CRIT)
					to_chat(user, "<span class='warning'>You cannot [key] while in a critical condition!</span>")
				if(UNCONSCIOUS, HARD_CRIT)
					to_chat(user, "<span class='warning'>You cannot [key] while unconscious!</span>")
				if(DEAD)
					to_chat(user, "<span class='warning'>You cannot [key] while dead!</span>")
			return FALSE
		if(hands_use_check && HAS_TRAIT(user, TRAIT_HANDS_BLOCKED))
			if(!intentional)
				return FALSE
			to_chat(user, "<span class='warning'>You cannot use your hands to [key] right now!</span>")
			return FALSE

	if(isliving(user))
		var/mob/living/L = user
		if(HAS_TRAIT(L, TRAIT_EMOTEMUTE))
			return FALSE

	return TRUE
/**
* Allows the intrepid coder to send a basic emote
* Takes text as input, sends it out to those who need to know after some light parsing
* If you need something more complex, make it into a datum emote
* Arguments:
* * text - The text to send out
*/
/mob/proc/manual_emote(text) //Just override the song and dance
	. = TRUE
	if(findtext(text, "their"))
		text = replacetext(text, "their", p_their())
	if(findtext(text, "them"))
		text = replacetext(text, "them", p_them())
	if(findtext(text, "%s"))
		text = replacetext(text, "%s", p_s())

	if(stat != CONSCIOUS)
		return

	if(!text)
		CRASH("Someone passed nothing to manual_emote(), fix it")

	log_message(text, LOG_EMOTE)

	var/ghost_text = "<b>[src]</b> " + text //Sin I know

	for(var/mob/M in GLOB.dead_mob_list)
		if(!M.client || isnewplayer(M))
			continue
		var/T = get_turf(src)
		if(M.stat == DEAD && M.client && (M.client.prefs.chat_toggles & CHAT_GHOSTSIGHT) && !(M in viewers(T, null)))
			M.show_message("[FOLLOW_LINK(M, src)] [ghost_text]")

	visible_message(text, visible_message_flags = EMOTE_MESSAGE)
