#js

// Shows import "name.volt": mathlib.volt (right next to this file) is
// plain Volt code - just functions - pasted in here before anything else
// compiles. See docs/REFERENCE.md's "Reusing code: import" section.
import "22_import_library_lib.volt"

print "5 squared is " + text(square(5))
print "3 cubed is " + text(cube(3))
