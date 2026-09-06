#pragma once

#include "StarConfig.hpp"

namespace Star {

extern char const* const OpenStarVersionString;
extern char const* const StarVersionString;
extern char const* const StarSourceIdentifierString;
extern char const* const StarArchitectureString;

// Generated fresh on every build invocation (see GenerateBuildStamp.cmake) -
// unlike StarSourceIdentifierString (the git commit), which only changes on
// an actual commit and so can't tell apart different uncommitted dev-loop
// builds of the same commit.
extern char const* const StarBuildStampString;
extern char const* const StarBuildUnixTimeString;
extern char const* const StarBuildDateString;

typedef uint32_t VersionNumber;

}
