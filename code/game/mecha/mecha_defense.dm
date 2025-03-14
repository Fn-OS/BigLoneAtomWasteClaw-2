/obj/mecha/proc/get_armour_facing(relative_dir)
	switch(relative_dir)
		if(180) // BACKSTAB!
			return facing_modifiers[BACK_ARMOUR]
		if(0, 45) // direct or 45 degrees off
			return facing_modifiers[FRONT_ARMOUR]
	return facing_modifiers[SIDE_ARMOUR] //if its not a front hit or back hit then assume its from the side

/obj/mecha/take_damage(damage_amount, damage_type = BRUTE, damage_flag = 0, sound_effect = 1, attack_dir)
	. = ..()
	if(. && obj_integrity > 0)
		spark_system.start()
		switch(damage_flag)
			if("fire")
				check_for_internal_damage(list(MECHA_INT_FIRE,MECHA_INT_TEMP_CONTROL))
			if("melee")
				check_for_internal_damage(list(MECHA_INT_TEMP_CONTROL,MECHA_INT_TANK_BREACH,MECHA_INT_CONTROL_LOST))
			else
				check_for_internal_damage(list(MECHA_INT_FIRE,MECHA_INT_TEMP_CONTROL,MECHA_INT_TANK_BREACH,MECHA_INT_CONTROL_LOST,MECHA_INT_SHORT_CIRCUIT))
		if(. >= 5 || prob(33))
			occupant_message("<span class='userdanger'>Taking damage!</span>")
			var/integrity = obj_integrity*100/max_integrity
			if(. && integrity < 20)
				to_chat(occupant, "[icon2html(src, occupant)][span_userdanger("HULL DAMAGE CRITICAL!")]")
				playsound(loc, 'sound/mecha/mecha_critical.ogg', 40, 1, -1)
		log_append_to_last("Took [damage_amount] points of damage. Damage type: \"[damage_type]\".",1)

/obj/mecha/run_obj_armor(damage_amount, damage_type, damage_flag = 0, attack_dir)
	. = ..()
	if(!damage_amount)
		return 0
	var/booster_deflection_modifier = 1
	var/booster_damage_modifier = 1
	if(damage_flag == "bullet" || damage_flag == "laser" || damage_flag == "energy")
		for(var/obj/item/mecha_parts/mecha_equipment/antiproj_armor_booster/B in equipment)
			if(B.projectile_react())
//				booster_deflection_modifier = B.deflect_coeff
				booster_damage_modifier = B.damage_coeff
				break
	else if(damage_flag == "melee")
		for(var/obj/item/mecha_parts/mecha_equipment/anticcw_armor_booster/B in equipment)
			if(B.attack_react())
//				booster_deflection_modifier *= B.deflect_coeff
				booster_damage_modifier *= B.damage_coeff
				break

	if(attack_dir)
		var/facing_modifier = get_armour_facing(abs(dir2angle(dir) - dir2angle(attack_dir)))
		booster_damage_modifier /= facing_modifier
		booster_deflection_modifier *= facing_modifier
	if(prob(deflect_chance * booster_deflection_modifier))
		visible_message("<span class='danger'>[src]'s armour deflects the attack!</span>")
		log_append_to_last("Armor saved.")
		return 0
	if(.)
		. *= booster_damage_modifier


/obj/mecha/on_attack_hand(mob/living/user, act_intent = user.a_intent, unarmed_attack_flags)
	user.do_attack_animation(src, ATTACK_EFFECT_PUNCH)
	playsound(loc, 'sound/weapons/tap.ogg', 40, 1, -1)
	user.visible_message("<span class='danger'>[user] hits [name]. Nothing happens</span>", null, null, COMBAT_MESSAGE_RANGE)
	mecha_log_message("Attack by hand/paw. Attacker - [user].", color="red")
	log_append_to_last("Armor saved.")

/obj/mecha/attack_paw(mob/user as mob)
	return attack_hand(user)


/obj/mecha/attack_alien(mob/living/user)
	mecha_log_message("Attack by alien. Attacker - [user].", color="red")
	playsound(src.loc, 'sound/weapons/slash.ogg', 100, 1)
	attack_generic(user, 15, BRUTE, "melee", 0)

/obj/mecha/attack_animal(mob/living/simple_animal/user)
	mecha_log_message("Attack by simple animal. Attacker - [user].", color="red")
	if(!user.melee_damage_upper && !user.obj_damage)
		user.emote("custom", message = "[user.friendly_verb_continuous] [src].")
		return 0
	else
		playsound(src, 'sound/effects/bang.ogg', 50, TRUE)
		log_combat(user, src, "attacked")
		var/animal_damage = rand(user.melee_damage_lower,user.melee_damage_upper)
		attack_generic(user, animal_damage, user.melee_damage_type, "melee")
		return 1


/obj/mecha/hulk_damage()
	return 15

/obj/mecha/attack_hulk(mob/living/carbon/human/user)
	. = ..()
	if(.)
		mecha_log_message("Attack by hulk. Attacker - [user].", color="red")
		log_combat(user, src, "punched", "hulk powers")

/obj/mecha/blob_act(obj/structure/blob/B)
	take_damage(30, BRUTE, "melee", 0, get_dir(src, B))

/obj/mecha/attack_tk()
	return

/obj/mecha/hitby(atom/movable/AM, skipcatch, hitpush, blocked, datum/thrownthing/throwingdatum) //wrapper
	mecha_log_message("Hit by [AM].", color="red")
	. = ..()


/obj/mecha/bullet_act(obj/item/projectile/Proj) //wrapper
	mecha_log_message("Hit by projectile. Type: [Proj.name]([Proj.flag]).", color="red")
	. = ..()

/obj/mecha/ex_act(severity, target)
	mecha_log_message("Affected by explosion of severity: [severity].", color="red")
	if(prob(deflect_chance))
		severity++
		log_append_to_last("Armor saved, changing severity to [severity].")
	. = ..()

/obj/mecha/contents_explosion(severity, target)
	severity++
	for(var/X in equipment)
		var/obj/item/mecha_parts/mecha_equipment/ME = X
		ME.ex_act(severity,target)
	for(var/Y in trackers)
		var/obj/item/mecha_parts/mecha_tracking/MT = Y
		MT.ex_act(severity, target)
	if(occupant)
		occupant.ex_act(severity,target)

/obj/mecha/handle_atom_del(atom/A)
	if(A == occupant)
		occupant = null
		icon_state = initial(icon_state)+"-open"
		setDir(dir_in)

/obj/mecha/emp_act(severity)
	. = ..()
	if (. & EMP_PROTECT_SELF)
		return
	if(get_charge())
		use_power(cell.charge*severity/100)
		take_damage(severity/3, BURN, "energy", 1)
	mecha_log_message("EMP detected", color="red")

	if(istype(src, /obj/mecha/combat))
		mouse_pointer = 'icons/mecha/mecha_mouse-disable.dmi'
		occupant?.update_mouse_pointer()
	if(!equipment_disabled && occupant) //prevent spamming this message with back-to-back EMPs
		to_chat(occupant, "<span=danger>Error -- Connection to equipment control unit has been lost.</span>")
	addtimer(CALLBACK(src, TYPE_PROC_REF(/obj/mecha, restore_equipment)), 3 SECONDS, TIMER_UNIQUE | TIMER_OVERRIDE)
	equipment_disabled = 1

/obj/mecha/temperature_expose(datum/gas_mixture/air, exposed_temperature, exposed_volume)
	if(exposed_temperature>max_temperature)
		mecha_log_message("Exposed to dangerous temperature.", color="red")
		take_damage(5, BURN, 0, 1)

/obj/mecha/attackby(obj/item/W as obj, mob/user as mob, params)

	if(istype(W, /obj/item/mmi))
		if(mmi_move_inside(W,user))
			to_chat(user, "[src]-[W] interface initialized successfully.")
		else
			to_chat(user, "[src]-[W] interface initialization failed.")
		return

	if(istype(W, /obj/item/mecha_ammo))
		ammo_resupply(W, user)
		return

	if(istype(W, /obj/item/mecha_parts/mecha_equipment))
		var/obj/item/mecha_parts/mecha_equipment/E = W
		spawn()
			if(E.can_attach(src))
				if(!user.temporarilyRemoveItemFromInventory(W))
					return
				E.attach(src)
				user.visible_message("[user] attaches [W] to [src].", "<span class='notice'>You attach [W] to [src].</span>")
			else
				to_chat(user, "<span class='warning'>You were unable to attach [W] to [src]!</span>")
		return
	if(W.GetID())
		if(add_req_access || maint_access)
			if(internals_access_allowed(user))
				var/obj/item/card/id/id_card
				if(istype(W, /obj/item/card/id))
					id_card = W
				else
					var/obj/item/pda/pda = W
					id_card = pda.id
				output_maintenance_dialog(id_card, user)
				return
			else
				to_chat(user, "<span class='warning'>Invalid ID: Access denied.</span>")
		else
			to_chat(user, "<span class='warning'>Maintenance protocols disabled by operator.</span>")
	else if(istype(W, /obj/item/wrench))
		if(state==1)
			state = 2
			to_chat(user, "<span class='notice'>You undo the securing bolts.</span>")
		else if(state==2)
			state = 1
			to_chat(user, "<span class='notice'>You tighten the securing bolts.</span>")
		return
	else if(istype(W, /obj/item/crowbar))
		if(state==2)
			state = 3
			to_chat(user, "<span class='notice'>You open the hatch to the power unit.</span>")
		else if(state==3)
			state=2
			to_chat(user, "<span class='notice'>You close the hatch to the power unit.</span>")
		return
	else if(istype(W, /obj/item/stack/cable_coil))
		if(state == 3 && (internal_damage & MECHA_INT_SHORT_CIRCUIT))
			if(W.use_tool(src, user, 0, 2))
				clearInternalDamage(MECHA_INT_SHORT_CIRCUIT)
				to_chat(user, "<span class='notice'>You replace the fused wires.</span>")
			else
				to_chat(user, "<span class='warning'>You need two lengths of cable to fix this mech!</span>")
		return
	else if(istype(W, /obj/item/screwdriver) && user.a_intent != INTENT_HARM)
		if(internal_damage & MECHA_INT_TEMP_CONTROL)
			clearInternalDamage(MECHA_INT_TEMP_CONTROL)
			to_chat(user, "<span class='notice'>You repair the damaged temperature controller.</span>")
		else if(state==3 && cell)
			cell.forceMove(loc)
			cell = null
			state = 4
			to_chat(user, "<span class='notice'>You unscrew and pry out the powercell.</span>")
			mecha_log_message("Powercell removed")
		else if(state==4 && cell)
			state=3
			to_chat(user, "<span class='notice'>You screw the cell in place.</span>")
		return

	else if(istype(W, /obj/item/stock_parts/cell))
		if(state==4)
			if(!cell)
				if(!user.transferItemToLoc(W, src))
					return
				var/obj/item/stock_parts/cell/C = W
				to_chat(user, "<span class='notice'>You install the powercell.</span>")
				cell = C
				mecha_log_message("Powercell installed")
			else
				to_chat(user, "<span class='notice'>There's already a powercell installed.</span>")
		return

	else if(istype(W, /obj/item/weldingtool) && user.a_intent != INTENT_HARM)
		user.DelayNextAction(CLICK_CD_MELEE)
		if(obj_integrity < max_integrity)
			if(W.use_tool(src, user, 0, volume=50, amount=1))
				if (internal_damage & MECHA_INT_TANK_BREACH)
					clearInternalDamage(MECHA_INT_TANK_BREACH)
					to_chat(user, "<span class='notice'>You repair the damaged gas tank.</span>")
				else
					user.visible_message("<span class='notice'>[user] repairs some damage to [name].</span>", "<span class='notice'>You repair some damage to [src].</span>")
					obj_integrity += min(10, max_integrity-obj_integrity)
					if(obj_integrity == max_integrity)
						to_chat(user, "<span class='notice'>It looks to be fully repaired now.</span>")
			return 1
		else
			to_chat(user, "<span class='warning'>The [name] is at full integrity!</span>")
		return 1

	else if(istype(W, /obj/item/mecha_parts/mecha_tracking))
		var/obj/item/mecha_parts/mecha_tracking/tracker = W
		tracker.try_attach_part(user, src)
		return
	else
		return ..()

/obj/mecha/attacked_by(obj/item/I, mob/living/user, attackchain_flags = NONE, damage_multiplier = 1)
	mecha_log_message("Attacked by [I]. Attacker - [user]")
	return ..()

/obj/mecha/proc/mech_toxin_damage(mob/living/target)
	playsound(src, 'sound/effects/spray2.ogg', 50, 1)
	if(target.reagents)
		if(target.reagents.get_reagent_amount(/datum/reagent/cryptobiolin) + force < force*2)
			target.reagents.add_reagent(/datum/reagent/cryptobiolin, force/2)
		if(target.reagents.get_reagent_amount(/datum/reagent/toxin) + force < force*2)
			target.reagents.add_reagent(/datum/reagent/toxin, force/2.5)


/obj/mecha/mech_melee_attack(obj/mecha/M)
	if(!has_charge(melee_energy_drain))
		return 0
	use_power(melee_energy_drain)
	if(M.damtype == BRUTE || M.damtype == BURN)
		log_combat(M.occupant, src, "attacked", M, "(INTENT: [uppertext(M.occupant.a_intent)]) (DAMTYPE: [uppertext(M.damtype)])")
		. = ..()

/obj/mecha/proc/full_repair(charge_cell)
	obj_integrity = max_integrity
	if(cell && charge_cell)
		cell.charge = cell.maxcharge
	if(internal_damage & MECHA_INT_FIRE)
		clearInternalDamage(MECHA_INT_FIRE)
	if(internal_damage & MECHA_INT_TEMP_CONTROL)
		clearInternalDamage(MECHA_INT_TEMP_CONTROL)
	if(internal_damage & MECHA_INT_SHORT_CIRCUIT)
		clearInternalDamage(MECHA_INT_SHORT_CIRCUIT)
	if(internal_damage & MECHA_INT_TANK_BREACH)
		clearInternalDamage(MECHA_INT_TANK_BREACH)
	if(internal_damage & MECHA_INT_CONTROL_LOST)
		clearInternalDamage(MECHA_INT_CONTROL_LOST)

/obj/mecha/narsie_act()
	emp_act(100)

/obj/mecha/ratvar_act()
	if((GLOB.ratvar_awakens || GLOB.clockwork_gateway_activated) && occupant)
		if(is_servant_of_ratvar(occupant)) //reward the minion that got a mech by repairing it
			full_repair(TRUE)
		else
			var/mob/living/L = occupant
			go_out(TRUE)
			if(L)
				L.ratvar_act()

/obj/mecha/do_attack_animation(atom/A, visual_effect_icon, obj/item/used_item, no_effect)
	if(!no_effect)
		if(selected)
			used_item = selected
		else if(!visual_effect_icon)
			visual_effect_icon = ATTACK_EFFECT_SMASH
			if(damtype == BURN)
				visual_effect_icon = ATTACK_EFFECT_MECHFIRE
			else if(damtype == TOX)
				visual_effect_icon = ATTACK_EFFECT_MECHTOXIN
	..()
