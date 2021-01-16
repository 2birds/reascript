--[[2Birds, 2021
Normalise selected MIDI notes
=============================
Translates velocity of selected MIDI notes into a given range while preserving relative differences.
Think of it as compression for MIDI, but being able to both expand and contract the range.]]

MIDI_VALUE_UPPER_BOUND=127
MIDI_VALUE_LOWER_BOUND=0

--Parse tokens from a CSV file into a table
function csvSplit(inputCSV)
    outResults = {}

    for word in string.gmatch(inputCSV, '([^,]+)') do 
        table.insert(outResults, word)
    end

    return outResults
end

-- Work out where the velocity value n sits in the new range
function normalise(n, oldMax, newRange, newLower)
    return math.floor(((n / oldMax) * newRange) + newLower)
end

function inRange(n, lowerBound, upperBound)
    return ((n >= lowerBound) and (n <= upperBound))
end

-- Get the notes we are operating on, make sure something is actually selected.
midiTake = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
if not midiTake then 
    reaper.ShowConsoleMsg("Nothing to normalise; no take selected.")
    return
end

-- Get user's preferred range.
retvals_csv = "0,127"
local _, retvals = reaper.GetUserInputs("Midi Velocity Normaliser", 2, "Minimum velocity,Maximum velocity", retvals_csv)
reaper.ShowConsoleMsg(string.format("User input: %s\n", retvals))

res = csvSplit(retvals)

-- Check that the values from the user input are sane
-- TODO: can this be checked in GetUserInputs()?
if (tonumber(res[1]) ~= nil and tonumber(res[2]) ~= nil) then 
    newLower = tonumber(res[1])
    newUpper = tonumber(res[2])
else
    reaper.ShowConsoleMsg("Could not normalise; both inputs must be numbers.")
    return
end

if newUpper <= newLower then
    reaper.ShowConsoleMsg("Could not normalise; newUpper limit must be greater than newLower limit.")
    return
end

if not (inRange(newLower, MIDI_VALUE_LOWER_BOUND, MIDI_VALUE_UPPER_BOUND) and inRange(newLower, MIDI_VALUE_LOWER_BOUND, MIDI_VALUE_UPPER_BOUND)) then
    reaper.ShowConsoleMsg("Could not normalise; both values must be between 0 and 127 (inclusive)")
    return
end

normalisedRange = newUpper - newLower

--Get the min and max values of the current midi velocities.
oldLower=MIDI_VALUE_UPPER_BOUND
oldUpper=MIDI_VALUE_LOWER_BOUND

local _, notes = reaper.MIDI_CountEvts(midiTake)

for i = 0, notes -1 do 
    _, selected, _, _, _, _, _, vel = reaper.MIDI_GetNote(midiTake, i)
    if selected then
        if vel < oldLower then
            oldLower = vel
        end

        if vel > oldUpper then
            oldUpper = vel
        end
    end
end

oldRange = oldUpper - oldLower

for i = 0, notes -1 do 
    retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(midiTake, i)
    if selected then 
        reaper.ShowConsoleMsg(string.format("Pitch: %d Velocity %d\n", pitch, vel))
        normalised_velocity = normalise(vel - oldLower, oldRange, normalisedRange, newLower)
        reaper.ShowConsoleMsg(string.format("Normalised value: %d\n", normalised_velocity))
        reaper.MIDI_SetNote(midiTake, i, selected, muted, startppqpos, endppqpos, chan, pitch, normalised_velocity)
    end
end