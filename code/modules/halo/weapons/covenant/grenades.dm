#define ADHERENCE_TIME 5 //If thrown before, does not stick.
#define FIZZLE_TIME 20  //If thrown after; does not stick.

//plasma grenade visual effect
/obj/effect/plasma_explosion
	name = "plasma blast"
	icon = 'code/modules/halo/weapons/covenant/plasma_explosion.dmi'
	icon_state = "plasma_explosion"
	var/lifetime = 7

/obj/effect/plasma_explosion/New()
	. = ..()
	pixel_x -= 32
	pixel_y -= 32
	spawn(lifetime)
		qdel(src)

//fuel rod visual effect
/obj/effect/plasma_explosion/green
	lifetime = 4
	icon_state = "green"

//Actual grenades//

/obj/item/weapon/grenade/plasma
	name = "Type-1 Antipersonnel Grenade"
	desc = "When activated, the coating of this grenade becomes a powerful adhesive, sticking to anyone it is thrown at. Heats to adherence in half a second, and loses that adherence after two."
	icon = 'code/modules/halo/weapons/icons/Covenant Weapons.dmi'
	icon_state = "plasmagrenade"
	throw_speed = 0 //sleep each tick
	det_time = 35
	can_adjust_timer = 0
	starttimer_on_hit = 1
	arm_sound = 'code/modules/halo/sounds/Plasmanadethrow.ogg'
	alt_explosion_range = 3
	alt_explosion_damage_max = 30
	matter = list("nanolaminate" = 1, "kemocite" = 1)
	salvage_components = list()
	item_state_slots = list(slot_l_hand_str = "plasma_nade_off", slot_r_hand_str = "plasma_nade_off")
	item_icons = list(\
		slot_l_hand_str = 'code/modules/halo/weapons/icons/Weapon_Inhands_left.dmi', \
		slot_r_hand_str = 'code/modules/halo/weapons/icons/Weapon_Inhands_right.dmi')
	var/activated_at = 0

/obj/item/weapon/grenade/plasma/activate(var/mob/living/carbon/human/h)
	item_state_slots = list(slot_l_hand_str = "plasma_nade_on", slot_r_hand_str = "plasma_nade_on")
	if(istype(h) && istype(h.species,/datum/species/unggoy) && prob(5))
		playsound(h.loc, 'code/modules/halo/sounds/unggoy_grenade_throw.ogg', 100)
	. = ..()
	activated_at = world.time
	if(istype(h))
		if(h.l_hand == src)
			h.update_inv_l_hand()
		else if(h.r_hand == src)
			h.update_inv_r_hand()

/obj/item/weapon/grenade/plasma/throw_impact(var/atom/A)
	if(!active)
		return
	start_timer()
	var/mob/living/L = A
	if(!istype(L))
		return
	var/timediff = world.time - activated_at
	if(timediff <= ADHERENCE_TIME || timediff > FIZZLE_TIME)
		A.visible_message("<span class = 'warning'>[src.name] bounces off of [L.name].</span>")
	else
		L.embed(src)
		A.visible_message("<span class = 'danger'>[src.name] sticks to [L.name]!</span>")
		det_time += 15
	. = ..()

/obj/item/weapon/grenade/plasma/detonate()
	var/turf/epicenter = get_turf(src)

	//visual effect
	var/obj/effect/plasma_explosion/P = new(epicenter)
	P.pixel_x += src.pixel_x
	P.pixel_y += src.pixel_y

	//the custom sfx itself
	for(var/mob/M in GLOB.player_list)
		if(M.z == epicenter.z)
			var/turf/M_turf = get_turf(M)
			var/dist = get_dist(M_turf, epicenter)
			// If inside the blast radius + world.view - 2
			if(dist <= round(alt_explosion_range + world.view - 2, 1))
				M.playsound_local(epicenter, 'code/modules/halo/sounds/Plasmanadedetonate.ogg', 100, 1)
	var/mob/living/carbon/human/mob_containing = loc
	if(istype(mob_containing))
		do_alt_explosion()
		explosion(get_turf(src), -1, 2, 2, 0)
		mob_containing.contents -= src
		mob_containing.embedded -= src
	else
		do_alt_explosion()
		explosion(get_turf(src), -1, 2, 2, 0)
	loc = null
	qdel(src)

/obj/item/weapon/grenade/plasma/suicide
	name = "Heavy Type-1 Antipersonnel Martydom Grenade"
	desc = "For only the most devoted of troops, this grenade is unthrowable, but can be dropped for a near instant explosion."
	det_time = 5
	throw_range = 0
	alt_explosion_range = 4
	alt_explosion_damage_max = 60
	
/obj/item/weapon/grenade/plasma/suicide/dropped(var/onto)
	. = ..()
	if(active == 1 && starttimer_on_hit)
		active = 2
		start_timer()

#undef ADHERENCE_TIME
