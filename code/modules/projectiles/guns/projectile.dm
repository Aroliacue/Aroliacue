#define HOLD_CASINGS	0 //do not do anything after firing. Manual action, like pump shotguns, or guns that want to define custom behaviour
#define CLEAR_CASINGS	1 //clear chambered so that the next round will be automatically loaded and fired, but don't drop anything on the floor
#define EJECT_CASINGS	2 //drop spent casings on the ground after firing
#define CYCLE_CASINGS	3 //cycle casings, like a revolver. Also works for multibarrelled guns
#define CASELESS		4 //leaves no casings

/obj/item/weapon/gun/projectile
	name = "gun"
	desc = "A gun that fires bullets."
	icon_state = "revolver"
	origin_tech = list(TECH_COMBAT = 2, TECH_MATERIAL = 2)
	w_class = ITEM_SIZE_NORMAL
	matter = list(DEFAULT_WALL_MATERIAL = 1000)

	var/caliber = "357"		//determines which casings will fit
	var/handle_casings = EJECT_CASINGS	//determines how spent casings should be handled
	var/ejection_angle = 90 //If we handle casings by ejecting them, which direction should we throw them? Angle between 1 to 360
	var/load_method = SINGLE_CASING|SPEEDLOADER //1 = Single shells, 2 = box or quick loader, 3 = magazine
	var/obj/item/ammo_casing/chambered = null

	//For SINGLE_CASING or SPEEDLOADER guns
	var/max_shells = 0				//the number of casings that will fit inside
	var/ammo_type = null			//the type of ammo that the gun comes preloaded with
	var/list/loaded = list()		//stored ammo
	var/starts_loaded = 1			//whether the gun starts loaded or not, can be overridden for guns crafted in-game

	//For MAGAZINE guns
	var/magazine_type = null    	//the type of magazine that the gun comes preloaded with
	var/obj/item/ammo_magazine/ammo_magazine = null //stored magazine
	var/allowed_magazines	    	//magazine types that may be loaded. Can be a list or single path
	var/auto_eject = 0		    	//if the magazine should automatically eject itself when empty.
	var/auto_eject_sound = null
	var/speed_reload_time = 0.4 SECONDS		//How long it takes to speed reload this gun. Set to -1 to disable.
	var/tactical_reload_time = 0.5 SECONDS	//How long it takes to tactically reload this gun. Set to -1 to disable.

	var/is_jammed = 0           	//Whether this gun is jammed
	var/jam_chance = 0          	//Chance it jams on fire
	var/sound/reload_sound = 'sound/weapons/empty.ogg'
	var/ammo_icon_state //Used to define a magazine icon state to render underneath the gun's icon.
	//TODO generalize ammo icon states for guns
	//var/magazine_states = 0
	//var/list/icon_keys = list()		//keys
	//var/list/ammo_states = list()	//values

/obj/item/weapon/gun/projectile/New()
	..()
	if (starts_loaded)
		if(ispath(ammo_type) && (load_method & (SINGLE_CASING|SPEEDLOADER)))
			for(var/i in 1 to max_shells)
				loaded += new ammo_type(src)
		if(ispath(magazine_type) && (load_method & MAGAZINE))
			ammo_magazine = new magazine_type(src)
	update_icon()

/obj/item/weapon/gun/projectile/proc/load_from_box(var/obj/item/ammo_box/box,var/mob/user)
	if(box.contents.len == 0 || isnull(box.contents.len))
		to_chat(user,"<span class ='notice'>The [box.name] is empty!</span>")
		return
	if(!(loaded.len <= max_shells))
		to_chat(user,"<span class = 'notice'>The [name] is full!</span>")
		return
	if(box.loading)
		to_chat(user,"<span class = 'notice'>[box] is already being used to load a gun!</span>")
		return
	to_chat(user,"<span class ='notice'>You start loading the [name] from the [box.name]</span>")
	box.loading = 1
	for(var/ammo in box.contents)
		if(do_after(user,box.load_time,box, 1, 1, INCAPACITATION_DEFAULT, 0, 0, 0))
			load_ammo(ammo,user)
			continue
		break
	box.loading = 0

	box.update_icon()

/obj/item/weapon/gun/projectile/consume_next_projectile()
	if(!is_jammed && prob(jam_chance))
		src.visible_message("<span class='danger'>\The [src] jams!</span>")
		is_jammed = 1
	if(is_jammed)
		return null
	//get the next casing
	if(loaded.len)
		chambered = loaded[1] //load next casing.
		if(handle_casings != HOLD_CASINGS)
			loaded -= chambered
	else if(ammo_magazine && ammo_magazine.stored_ammo.len)
		chambered = ammo_magazine.stored_ammo[ammo_magazine.stored_ammo.len]
		if(handle_casings != HOLD_CASINGS)
			ammo_magazine.stored_ammo -= chambered

	if (chambered)
		return chambered.BB
	return null

/obj/item/weapon/gun/projectile/handle_post_fire()
	..()
	if(chambered)
		chambered.expend()
	process_chambered()

/obj/item/weapon/gun/projectile/handle_click_empty()
	..()
	process_chambered()

/obj/item/weapon/gun/projectile/proc/process_chambered()
	if (!chambered) return
	if(handle_casings == EJECT_CASINGS)
		var/obj/item/ammo_casing/to_eject = chambered
		spawn()
			to_eject.eject(get_turf(src), angle2dir(dir2angle(loc.dir)+ejection_angle))
	if(handle_casings == CYCLE_CASINGS)
		if(ammo_magazine)
			ammo_magazine.stored_ammo += chambered
		else
			loaded += chambered
	if(handle_casings == CASELESS)
		qdel(chambered)
	if(handle_casings != HOLD_CASINGS)
		chambered = null

//Attempts to load A into src, depending on the type of thing being loaded and the load_method
//Maybe this should be broken up into separate procs for each load method?
/obj/item/weapon/gun/projectile/proc/load_ammo(var/obj/item/A, mob/user)
	var/list/attachments = get_attachments()
	if(attachments.len > 0)
		var/load_success = 0
		for(var/obj/item/weapon_attachment/secondary_weapon/attachment in get_attachments())
			if(!istype(A,attachment.ammotype))
				continue
			var/load_succeed = attachment.load_attachment(A,user)
			if(load_succeed == 1)
				load_success = 1
		if(load_success)
			return //if one of our attachments have fired, let's not fire normally.

	if(istype(A, /obj/item/ammo_magazine))
		var/obj/item/ammo_magazine/AM = A
		if(!(load_method & AM.mag_type) || caliber != AM.caliber)
			return //incompatible

		switch(AM.mag_type)
			if(MAGAZINE)
				if((ispath(allowed_magazines) && !istype(A, allowed_magazines)) || (islist(allowed_magazines) && !is_type_in_list(A, allowed_magazines)))
					to_chat(user, "<span class='warning'>\The [A] won't fit into [src].</span>")
					return
				var/reloadmessage = "insert"
				if(ammo_magazine)
					if(user.a_intent == I_HELP || user.a_intent == I_DISARM)
						to_chat(user, "<span class='warning'>[src] already has a magazine loaded.</span>")//already a magazine here
						return
					else
						if(user.a_intent == I_GRAB) //Tactical reloading
							if(tactical_reload_time == -1)
								to_chat(user, "<span class='warning'>You can't tactically reload this gun!</span>")
								return
							if(!do_after(user, tactical_reload_time, src,same_loc = 0))
								return
							user.remove_from_mob(AM)
							AM.loc = src
							ammo_magazine.update_icon()
							user.put_in_hands(ammo_magazine)
							reloadmessage = "tactically reload"
						else //Speed reloading
							if(!speed_reload_time == -1)
								to_chat(user, "<span class='warning'>You can't speed reload with this gun!</span>")
								return
							if(!do_after(user, speed_reload_time, src,same_loc = 0))
								return
							user.remove_from_mob(AM)
							AM.loc = src.loc
							ammo_magazine.update_icon()
							ammo_magazine.dropInto(user.loc)
							reloadmessage = "speed reload"
				if(reloadmessage == "insert") //this is done to make speed reloading drop the mag on the floor like it should
					user.remove_from_mob(AM)
					AM.loc = src.loc
				ammo_magazine = AM
				user.visible_message("<span class ='warning'>\The [user] [reloadmessage]s[reloadmessage == "insert" ? " \the [AM] into" : ""] \the [src].</span>",
				"<span class='notice'>You [reloadmessage][reloadmessage == "insert" ? " \the [AM] into" : ""] \the [src].</span>")
				playsound(src.loc, reload_sound, 50, 1)
			if(SPEEDLOADER)
				if(loaded.len >= max_shells)
					to_chat(user, "<span class='warning'>[src] is full!</span>")
					return
				var/count = 0
				for(var/obj/item/ammo_casing/C in AM.stored_ammo)
					if(loaded.len >= max_shells)
						break
					if(C.caliber == caliber)
						C.loc = src
						loaded += C
						AM.stored_ammo -= C //should probably go inside an ammo_magazine proc, but I guess less proc calls this way...
						count++
				if(count)
					user.visible_message("[user] reloads [src].", "<span class='notice'>You load [count] round\s into [src].</span>")
					playsound(src.loc, reload_sound, 50, 1)
		AM.update_icon()
	else if(istype(A, /obj/item/ammo_casing))
		var/obj/item/ammo_casing/C = A
		if(!(load_method & SINGLE_CASING) || caliber != C.caliber)
			return //incompatible
		if(loaded.len >= max_shells)
			to_chat(user, "<span class='warning'>[src] is full.</span>")
			return

		user.remove_from_mob(C)
		C.loc = src
		loaded.Insert(1, C) //add to the head of the list
		user.visible_message("[user] inserts \a [C] into [src].", "<span class='notice'>You insert \a [C] into [src].</span>")
		playsound(src.loc, reload_sound, 50, 1)

	update_icon()

//attempts to unload src. If allow_dump is set to 0, the speedloader unloading method will be disabled
/obj/item/weapon/gun/projectile/proc/unload_ammo(mob/user, var/allow_dump=1)
	//first checks if we're unloading a secondary weapon
	var/list/attachments = get_attachments()
	if(attachments.len > 0)
		var/have_unloaded = 0
		for(var/obj/item/weapon_attachment/secondary_weapon/attachment in get_attachments())
			if(attachment.alt_fire_active == 1)
				attachment.unload_attachment(user)
				have_unloaded = 1
		if(have_unloaded)
			return //having unloaded your secondary weapon you don't want to unload your primary weapon too
	if(is_jammed)
		user.visible_message("\The [user] begins to unjam [src].", "You clear the jam and unload [src]")
		if(!do_after(user, 4, src))
			return
		is_jammed = 0
		playsound(src.loc, 'sound/weapons/flipblade.ogg', 50, 1)
	if(ammo_magazine)
		user.put_in_hands(ammo_magazine)
		user.visible_message("[user] removes [ammo_magazine] from [src].", "<span class='notice'>You remove [ammo_magazine] from [src].</span>")
		playsound(src.loc,'sound/weapons/empty.ogg', 50, 1)
		ammo_magazine.update_icon()
		ammo_magazine = null
	else if(loaded.len)
		//presumably, if it can be speed-loaded, it can be speed-unloaded.
		if(allow_dump && (load_method & SPEEDLOADER))
			var/count = 0
			var/turf/T = get_turf(user)
			if(T)
				for(var/obj/item/ammo_casing/C in loaded)
					C.loc = T
					count++
				loaded.Cut()
			if(count)
				user.visible_message("[user] unloads [src].", "<span class='notice'>You unload [count] round\s from [src].</span>")
		else if(load_method & SINGLE_CASING)
			var/obj/item/ammo_casing/C = loaded[loaded.len]
			loaded.len--
			user.put_in_hands(C)
			user.visible_message("[user] removes \a [C] from [src].", "<span class='notice'>You remove \a [C] from [src].</span>")
	else
		to_chat(user, "<span class='warning'>[src] is empty.</span>")
	update_icon()

/obj/item/weapon/gun/projectile/attackby(var/obj/item/A as obj, mob/user as mob)
	if(istype(A,/obj/item/ammo_box))
		load_from_box(A,user)
	. = ..()
	load_ammo(A, user)

/obj/item/weapon/gun/projectile/attack_self(mob/user as mob)
	if(stored_targ)
		to_chat(user,"<span class = 'notice'>You stop your sustained burst from [src]</span>")
		stored_targ = null
		return
	unload_ammo(user)

/obj/item/weapon/gun/projectile/attack_hand(mob/user as mob)
	if(user.get_inactive_hand() == src)
		unload_ammo(user, allow_dump=0)
	else
		return ..()

/obj/item/weapon/gun/projectile/afterattack(atom/A, mob/living/user)
	..()
	if(auto_eject && ammo_magazine && ammo_magazine.stored_ammo && !ammo_magazine.stored_ammo.len)
		ammo_magazine.loc = get_turf(src.loc)
		user.visible_message(
			"[ammo_magazine] falls out and clatters on the floor!",
			"<span class='notice'>[ammo_magazine] falls out and clatters on the floor!</span>"
			)
		if(auto_eject_sound)
			playsound(user, auto_eject_sound, 40, 1)
		ammo_magazine.update_icon()
		ammo_magazine = null
		update_icon() //make sure to do this after unsetting ammo_magazine

/obj/item/weapon/gun/projectile/examine(mob/user)
	. = ..(user)
	if(is_jammed)
		to_chat(user, "<span class='warning'>It looks jammed.</span>")
	if(ammo_magazine)
		to_chat(user, "It has \a [ammo_magazine] loaded.")
	to_chat(user, "Has [getAmmo()] round\s remaining.")
	return

/obj/item/weapon/gun/projectile/proc/getAmmo()
	var/bullets = 0
	if(loaded)
		bullets += loaded.len
	if(ammo_magazine && ammo_magazine.stored_ammo)
		bullets += ammo_magazine.stored_ammo.len
	if(chambered)
		bullets += 1
	return bullets

/obj/item/weapon/gun/projectile/update_icon()
	. = ..()
	if(ammo_magazine && ammo_icon_state)
		underlays += image(icon = src.icon,icon_state = src.ammo_icon_state)
		
/obj/item/weapon/gun/projectile/ammo_check() 
	
	var/ammo = getAmmo()  //Already have a proc to fetch us the ammo unique to projectiles
	
	return ammo

/* Unneeded -- so far.
//in case the weapon has firemodes and can't unload using attack_hand()
/obj/item/weapon/gun/projectile/verb/unload_gun()
	set name = "Unload Ammo"
	set category = "Object"
	set src in usr

	if(usr.stat || usr.restrained()) return

	unload_ammo(usr)
*/
