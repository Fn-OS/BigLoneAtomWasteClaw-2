/**
 * Causes weather to occur on a z level in certain area types
 *
 * The effects of weather occur across an entire z-level. For instance, lavaland has periodic ash storms that scorch most unprotected creatures.
 * Weather always occurs on different z levels at different times, regardless of weather type.
 * Can have custom durations, targets, and can automatically protect indoor areas.
 *
 */

/* Removing weather because of crashes
/datum/weather
	/// name of weather
	var/name = "space wind"
	/// description of weather
	var/desc = "Heavy gusts of wind blanket the area, periodically knocking down anyone caught in the open."

	/// The message displayed in chat to foreshadow the weather's beginning
	var/telegraph_message = "<span class='warning'>The wind begins to pick up.</span>"

	/// In deciseconds, how long from the beginning of the telegraph until the weather begins
	var/telegraph_duration = 300
	/// The sound file played to everyone on an affected z-level
	var/telegraph_sound
	/// The overlay applied to all tiles on the z-level
	var/telegraph_overlay
	/// Displayed in chat once the weather begins in earnest
	var/weather_message = "<span class='userdanger'>The wind begins to blow ferociously!</span>"
	///In deciseconds, how long the weather lasts once it begins
	var/weather_duration = 1200
	///See above - this is the lowest possible duration
	var/weather_duration_lower = 1200
	///See above - this is the highest possible duration
	var/weather_duration_upper = 1500
	/// Looping sound while weather is occuring
	var/weather_sound
	/// Area overlay while the weather is occuring
	var/weather_overlay
	/// Color to apply to the area while weather is occuring
	var/weather_color = null

	/// Displayed once the weather is over
	var/end_message = "<span class='danger'>The wind relents its assault.</span>"
	/// In deciseconds, how long the "wind-down" graphic will appear before vanishing entirely
	var/end_duration = 300
	/// Sound that plays while weather is ending
	var/end_sound
	/// Area overlay while weather is ending
	var/end_overlay

	/// Types of area(s) to affect
	var/area_types = list(/area/space)
	/// TRUE value protects areas with outdoors marked as false, regardless of area type
	var/protect_indoors = FALSE
	/// Areas to be affected by the weather, calculated when the weather begins
	var/list/impacted_areas = list()

	/// Areas that are protected and excluded from the affected areas.
	var/list/protected_areas = list()
	/// The list of z-levels that this weather is actively affecting
	var/impacted_z_levels

	/// Since it's above everything else, this is the layer used by default. TURF_LAYER is below mobs and walls if you need to use that. 
	var/overlay_layer = AREA_LAYER 
	/// Plane for the overlay
	var/overlay_plane = BLACKNESS_PLANE
	/// If the weather has no purpose but aesthetics. 
	var/aesthetic = FALSE
	/// Used by mobs to prevent them from being affected by the weather 
	var/immunity_type = "storm"

	/// The stage of the weather, from 1-4
	var/stage = END_STAGE

	/// Weight amongst other eligible weather. if zero, will never happen randomly.
	var/probability = 0
	/// The z-level trait to affect when run randomly or when not overridden.
	var/target_trait = ZTRAIT_STATION

	/// Whether a barometer can predict when the weather will happen
	var/barometer_predictable = FALSE
	/// For barometers to know when the next storm will hit
	var/next_hit_time = 0
	
	var/affects_turfs = FALSE //Does this weather affect turfs at all?
	var/turfs_impacted = FALSE // Did this weather already impact turfs?
	var/carbons_only = FALSE //Does this weather affect only carbon mobs?

/datum/weather/New(z_levels)
	..()
	impacted_z_levels = z_levels

/**
 * Telegraphs the beginning of the weather on the impacted z levels
 *
 * Sends sounds and details to mobs in the area
 * Calculates duration and hit areas, and makes a callback for the actual weather to start
 *
 */
/datum/weather/proc/telegraph()
	if(stage == STARTUP_STAGE)
		return
	stage = STARTUP_STAGE
	var/list/affectareas = list()
	for(var/area_type in area_types)
		for(var/V in get_areas(area_type))
			var/area/A = V
			affectareas |= A
			if(A.sub_areas)
				affectareas |= A.sub_areas
	for(var/V in protected_areas)
		affectareas -= get_areas(V)
	for(var/V in affectareas)
		var/area/A = V
		if(protect_indoors && !A.outdoors)
			continue
		if(A.z in impacted_z_levels)
			impacted_areas |= A
	weather_duration = rand(weather_duration_lower, weather_duration_upper)
	START_PROCESSING(SSweather, src)			//The reason this doesn't start and stop at main stage is because processing list is also used to see active running weathers (for example, you wouldn't want two ash storms starting at once.)
	update_areas()
	alert_players(telegraph_message, telegraph_sound)
	addtimer(CALLBACK(src, PROC_REF(start)), telegraph_duration)

/**
 * Starts the actual weather and effects from it
 *
 * Updates area overlays and sends sounds and messages to mobs to notify them
 * Begins dealing effects from weather to mobs in the area
 *
 */
/datum/weather/proc/start()
	if(stage >= MAIN_STAGE)
		return
	stage = MAIN_STAGE
	update_areas()
	alert_players(weather_message, weather_sound)
	addtimer(CALLBACK(src, PROC_REF(wind_down)), weather_duration)

/**
 * Weather enters the winding down phase, stops effects
 *
 * Updates areas to be in the winding down phase
 * Sends sounds and messages to mobs to notify them
 *
 */
/datum/weather/proc/wind_down()
	if(stage >= WIND_DOWN_STAGE)
		return
	stage = WIND_DOWN_STAGE
	update_areas()
	alert_players(end_message, end_sound)
	addtimer(CALLBACK(src, PROC_REF(end)), end_duration)

/datum/weather/proc/alert_players(message, sound_play)
	if(!message && !sound_play)
		return FALSE
	for(var/M in GLOB.player_list)
		var/turf/mob_turf = get_turf(M)
		if(mob_turf && (mob_turf.z in impacted_z_levels))
			if(end_message)
				to_chat(M, end_message)
			if(end_sound)
				SEND_SOUND(M, sound(end_sound))
	addtimer(CALLBACK(src, .proc/end), end_duration)

/**
 * Fully ends the weather
 *
 * Effects no longer occur and area overlays are removed
 * Removes weather from processing completely
 *
 */
/datum/weather/proc/end()
	if(stage == END_STAGE)
		return 1
	stage = END_STAGE
	STOP_PROCESSING(SSweather, src)
	update_areas()

/datum/weather/process()
	if(aesthetic || (stage != MAIN_STAGE))
		return
	if(!turfs_impacted && affects_turfs)
		turfs_impacted = TRUE
		for(var/i in impacted_areas)
			var/area/A = i
			for(var/turf/T in get_area_turfs(A))
				weather_act_turf(T)
	for(var/i in (carbons_only ? GLOB.carbon_list : GLOB.mob_living_list))
		var/mob/living/L = i
		if(can_weather_act(L))
			weather_act(L)

/**
 * Returns TRUE if the living mob can be affected by the weather
 *
 */
/datum/weather/proc/can_weather_act(mob/living/L)
	var/turf/mob_turf = get_turf(L)
	if(mob_turf && !(mob_turf.z in impacted_z_levels))
		return
	if(immunity_type in L.weather_immunities)
		return
	if(!(get_area(L) in impacted_areas))
		return
	return TRUE

/**
 * Affects the mob with whatever the weather does
 *
 */
/datum/weather/proc/weather_act(mob/living/L)
	return

/**
 * Affects a turf, ONCE, with whatever the weather does
 *
 */
/datum/weather/proc/weather_act_turf(turf/T)
	return


/**
 * Updates the overlays on impacted areas
 *
 */
/datum/weather/proc/update_areas()
	for(var/V in impacted_areas)
		var/area/N = V
		N.layer = overlay_layer
		N.icon = 'icons/effects/weather_effects.dmi'
		N.color = weather_color
		switch(stage)
			if(STARTUP_STAGE)
				N.icon_state = telegraph_overlay
			if(MAIN_STAGE)
				N.icon_state = weather_overlay
			if(WIND_DOWN_STAGE)
				N.icon_state = end_overlay
			if(END_STAGE)
				N.color = null
				N.icon_state = ""
				N.icon = 'icons/turf/areas.dmi'
				N.layer = AREA_LAYER //Just default back to normal area stuff since I assume setting a var is faster than initial
				N.set_opacity(FALSE)
*/
