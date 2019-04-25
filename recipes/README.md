# Recipes

Because Collapse OS is a meta OS that you assemble yourself on an improvised
machine of your own design, there can't really be a build script. Not a
reliable one anyways.

Because the design of post-collapse machines is hard to predict, it's hard to
write a definitive guide to it.

The approach we're taking here is a list of recipes: Walkthrough guides for
machines that were built and tried pre-collapse. With a wide enough variety of
recipes, I hope that it will be enough to cover most post-collapse cases.

That's what this folder contains: a list of recipes that uses parts supplied
by Collapse OS to run on some machines people tried.

In other words, parts often implement logic for hardware that isn't available
off the shelf, but they implement a logic that you are likely to need post
collapse. These parts, however *have* been tried on real material and they all
have a recipe describing how to build the hardware that parts have been written
for.

## Structure

Each top folder represent an architecture. In that top folder, there's a
`README.md` file presenting the architecture as well as instructions to
minimally get Collapse OS running on it. Then, in the same folder, there are
auxiliary recipes for nice stuff built around that architecture.

The structure of those recipes follow a regular pattern: pre-collapse recipe
and post-collapse recipe. That is, instructions to achieve the desired outcome
from a "modern" system, and then, instructions to achieve the same thing from a
system running Collapse OS.

Initially, those recipes will only be possible in a "modern" system, but as
tooling improve, we should be able to have recipes that we can consider
complete.
