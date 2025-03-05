#define MINIMUM_USEFUL_LIGHT_RANGE 1.4

// The proc you should always use to set the light of this atom.
// Nonesensical value for l_color default, so we can detect if it gets set to null.
#define NONSENSICAL_VALUE -99999
/atom/proc/set_light(l_range, l_power, l_color=NONSENSICAL_VALUE)
	if(l_range > 0 && l_range < MINIMUM_USEFUL_LIGHT_RANGE)
		l_range = MINIMUM_USEFUL_LIGHT_RANGE	//Brings the range up to 1.4, which is just barely brighter than the soft lighting that surrounds players.

	if(l_range != null) light_range = l_range
	if(l_power != null) light_power = l_power
	if(l_color != NONSENSICAL_VALUE) light_color = l_color

	update_light()

#undef NONSENSICAL_VALUE

// Will update the light (duh).
// Creates or destroys it if needed, makes it update values, makes sure it's got the correct source turf...
/atom/proc/update_light()
	set waitfor = FALSE
	if (QDELETED(src))
		return

	if(!light_power || !light_range) // We won't emit light anyways, destroy the light source.
		if(light)
			light.destroy()
			light = null
	else
		if(!istype(loc, /atom/movable)) // We choose what atom should be the top atom of the light here.
			. = src
		else
			. = loc

		if(light) // Update the light or create it if it does not exist.
			light.update(.)
		else
			light = new/datum/light_source(src, .)

// Incase any lighting vars are on in the typepath we turn the light on in New().
/atom/proc/init_light()
	if(light_power && light_range)
		update_light()

	if(opacity && isturf(loc))
		var/turf/T = loc
		T.has_opaque_atom = TRUE // No need to recalculate it in this case, it's guaranteed to be on afterwards anyways.

/atom/movable/init_light()
	. = ..()

	if(opacity && isturf(loc))
		var/turf/T = loc
		T.reconsider_lights()

	if(istype(loc, /turf/open))
		var/turf/open/open = loc
		if(open.isOpen())
			open.fallThrough(src)

// If we have opacity, make sure to tell (potentially) affected light sources.
/atom/movable/Destroy()
	var/turf/T = loc
	if(opacity && istype(T))
		set_opacity(FALSE)
	return ..()

// Should always be used to change the opacity of an atom.
// It notifies (potentially) affected light sources so they can update (if needed).
/atom/movable/set_opacity(new_opacity)
	. = ..()
	if (!.)
		return

	opacity = new_opacity
	var/turf/T = loc
	if (!isturf(T))
		return

	if (new_opacity == TRUE)
		T.has_opaque_atom = TRUE
		T.reconsider_lights()
	else
		var/old_has_opaque_atom = T.has_opaque_atom
		T.recalc_atom_opacity()
		if (old_has_opaque_atom != T.has_opaque_atom)
			T.reconsider_lights()
