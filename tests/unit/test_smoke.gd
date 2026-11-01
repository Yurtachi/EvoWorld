extends RefCounted

func run() -> Array:
	var errs := []
	if 1 + 1 != 2:
		errs.append("arithmetic broken")
	return errs
