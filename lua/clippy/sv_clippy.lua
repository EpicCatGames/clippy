---- Backwards compatibility with ancient visual clip data
--duplicator.RegisterEntityModifier( "clips", function( pl, ent, data ) 
--
--    if ( !IsValid( ent ) ) then return end
--
--    if ( data ) then
--
--        for _, oldclip in pairs( data ) do
--
--            timer.Simple( 5, function()
--
--                Clippy.Log("converting old clip format to new format")
--
--                Clippy.RegisterClip( ent, oldclip.n, oldclip.d, oldclip.inside )
--
--            end )
--
--        end
--
--    else
--
--        Clippy.Log(tostring( ent ) .." should have had old visclips, but data was invalid!")
--
--    end
--
--end )
--
---- Register entity modifier with the duplicator library
--duplicator.RegisterEntityModifier( "clippy", function( pl, ent, data )
--
--    if ( !IsValid( ent ) ) then return end
--
--    if ( data ) then
--        
--        -- investigate only sending when the duplication has finished for better performance
--        for _, clip in pairs( data ) do
--
--            -- Let the entity become valid on the client before sending them the clip data?
--            timer.Simple( 5, function()
--
--                Clippy.RegisterClip( ent, clip.Ang, clip.Distance, clip.Inside )
--
--            end )
--
--        end
--
--    end
--
--end )

-- Setup clips from pastes and network them all at once, instead of one at a time like the old tool
hook.Add( "AdvDupe_FinishPasting", "ClippyAdvDupeFinishPasting", function( tbl )

    local DupeData = tbl[1]

    if ( DupeData == nil ) then return end

    Clippy.Log( "AdvDupe2 finished pasting dupe with ".. tostring( table.Count( DupeData.EntityList ) ) .." entities" )

    -- Table of clips to be networked
    local Clips = { }

    -- Loop through CreatedEntities, check their EntityMods for clip data, build a table of clip data, send all at once to players
    for _, ent in pairs( DupeData.CreatedEntities ) do

        local OldClips = ent.EntityMods["clips"] or { }
        local NewClips = ent.EntityMods["clippy"] or { }

        if ( #OldClips == 0 and #NewClips == 0 ) then continue end

        -- Build the clips table on the ent and for networking
        ent.ClippyData = ent.ClippyData or { }

        for _, clip in pairs( OldClips ) do

            table.insert( Clips, {
                EntIndex = ent:EntIndex(),
                Version = clip.Version or 0,
                Ang = Clippy.AngleToString( clip.n ),
                Distance = Clippy.DistanceToString( clip.d ),
                Inside = (clip.inside and 1 or 0)
            } )

            table.insert( ent.ClippyData, {
                Version = clip.Version,
                Ang = clip.n,
                Distance = clip.d,
                Inside = clip.inside
            } )

            -- NOTE: @looter keep a special table of the old clips for re-populating the "clips" duplicator modifier?

        end

        for _, clip in pairs( NewClips ) do

            table.insert( Clips, {
                EntIndex = ent:EntIndex(),
                Version = clip.Version or 0,
                Ang = Clippy.AngleToString( clip.Ang ),
                Distance = Clippy.DistanceToString( clip.Distance ),
                Inside = (clip.Inside and 1 or 0)
            } )

            table.insert( ent.ClippyData, {
                Version = clip.Version or 0,
                Ang = clip.Ang,
                Distance = clip.Distance,
                Inside = clip.Inside
            } )

        end

        -- Store in the global clipped ents table for persistence
        if ( !table.HasValue( Clippy.Clips, ent ) ) then

            table.insert( Clippy.Clips, ent )

        end

        -- Store the clips back on the entity itself
        if ( #NewClips > 0 ) then

            duplicator.StoreEntityModifier( ent, "clippy", ent.ClippyData )
            
        end

        if ( #OldClips > 0 ) then
            
            duplicator.StoreEntityModifier( ent, "clips", OldClips )

        end

    end

    -- Send the clips over the network
    if ( #Clips > 0 ) then
        
        Clippy.Log("networking ".. tostring( #Clips ) .." clips from a paste to all players")

        net.Start( "clippy_clips" )
            net.WriteStructure( "clippy_clips", { Clips = Clips } )
        net.Broadcast()

    end

end )

-- Setup the undo table entry for a clip
function Clippy.CreateUndo( ent, pl, id )

    if ( !IsValid( ent ) or !IsValid( pl ) ) then return end

    ent.ClippyUndoers = ent.ClippyUndoers or { }

    undo.Create( "clip" )
        undo.AddFunction( Clippy.UnregisterClip, ent, id )
        undo.SetPlayer( pl )
        undo.SetCustomUndoText( "Undone visual clip" )
    undo.Finish()

    local undos = undo.GetTable()
    local numUndos = #undos[ pl:UniqueID() ]
    local lastUndo = undos[ pl:UniqueID() ][ numUndos ]

    lastUndo.ClipEnt = ent
    lastUndo.ClipId = id

    local uid = pl:UniqueID()

    if ( !table.HasValue( ent.ClippyUndoers, uid ) ) then
        
        table.insert( ent.ClippyUndoers, uid )

    end

end

-- Cleanup the undo table entries for an entity
function Clippy.CleanupUndos( ent )

    if ( !IsValid( ent ) ) then return end
    if ( ent.ClippyUndoers == nil or #ent.ClippyUndoers == 0 ) then return end

    Clippy.Log( "cleaning up clip undos for ".. tostring( ent ) )

    local undos = undo.GetTable()
 
    for _, playerId in pairs( ent.ClippyUndoers ) do

        local playerTable = undos[ playerId ]

        if ( playerTable == nil ) then continue end

        for undoId, undoEntry in pairs( table.Reverse( playerTable ) ) do

            if ( undoEntry.Name == "clip" and undoEntry.ClipEnt != nil and undoEntry.ClipEnt == ent ) then

                Clippy.Log( "removing undo ".. tostring( undoId ) .." for ".. tostring( playerId ) )

                table.RemoveByValue( playerTable, undoEntry )

            end

        end

    end

end

-- Cleanup the undo entry for a specific clip
function Clippy.CleanupUndo( ent, id )

    if ( !IsValid( ent ) ) then return end
    if ( ent.ClippyUndoers == nil or #ent.ClippyUndoers == 0 ) then return end

    Clippy.Log( "cleaning up clip undo for ".. tostring( ent ) .." clip ".. tostring( id ) )

    local undos = undo.GetTable()
 
    for _, playerId in pairs( ent.ClippyUndoers ) do

        local playerTable = undos[ playerId ]

        if ( playerTable == nil ) then continue end

        for undoId, undoEntry in pairs( table.Reverse( playerTable ) ) do

            if ( undoEntry.Name == "clip" and undoEntry.ClipEnt != nil and undoEntry.ClipEnt == ent and undoEntry.ClipId == id ) then

                Clippy.Log( "removing undo ".. tostring( undoId ) .." for ".. tostring( playerId ) )

                table.RemoveByValue( playerTable, undoEntry )

            end

        end

    end

end

-- Called when a prop with clips has been removed
local function ClippyOnRemoved( ent )

    if ( !IsValid( ent ) ) then return end

    table.RemoveByValue( Clippy.Clips, ent )

    -- Remove all clip undos for this ent
    Clippy.CleanupUndos( ent )

end

-- TODO: @looter Some of these functions perform similar tasks, and could be merged (Update, SendClip, Unregister, Remove)

-- Register a new clip
function Clippy.RegisterClip( ent, ang, distance, inside )

    if ( !IsValid( ent ) ) then
        Clippy.Log("RegisterClip received invalid entity")
        return nil
    end

    ent.ClippyData = ent.ClippyData or { }

    Clippy.Log("RegisterClip ".. tostring(ent) .." ".. tostring(ang) .." ".. tostring(distance) .." ".. tostring(inside))

    local id = table.insert( ent.ClippyData, {
        Version = Clippy.Version,
        Ang = ang,
        Distance = distance,
        Inside = inside
    } )

    duplicator.StoreEntityModifier( ent, "clippy", ent.ClippyData )

    if ( !table.HasValue( Clippy.Clips, ent ) ) then

        table.insert( Clippy.Clips, ent )

    end

    ent:CallOnRemove( "ClippyOnRemoved", ClippyOnRemoved )

    Clippy.SendClip( ent, nil, id )

    return id

end

-- Unregister a clip by its index
function Clippy.UnregisterClip( tbl, ent, id )

    Clippy.Log("UnregisterClip called for ".. tostring( ent ) .." ".. tostring( id ))

    if ( !IsValid( ent ) ) then 
        Clippy.Log("UnregisterClip ent was invalid")
        return 
    end

    if ( ent.ClippyData != nil and ent.ClippyData[id] != nil ) then
        
        table.remove( ent.ClippyData, id )

        if ( #ent.ClippyData == 0 ) then
            
            Clippy.Log("unregistering all clips associated with ".. tostring(ent))

            table.RemoveByValue( Clippy.Clips, ent )

            Clippy.UnregisterClips( ent )

        else

            Clippy.Log("unregistered clip ".. tostring(id) .." for ".. tostring(ent))

            net.Start( "clippy_undo" )
                net.WriteEntity( ent )
                net.WriteUInt( id, 8 )
            net.Broadcast()

            Clippy.CleanupUndo( ent, id )

            duplicator.StoreEntityModifier( ent, "clippy", ent.ClippyData )

        end

    else

        Clippy.Log("UnregisterClip failed because ".. tostring( ent ) .." had no clip data for clip ".. tostring( id ))

    end

end

-- Unregister all clips for an entity
function Clippy.UnregisterClips( ent )

    if ( !IsValid( ent ) ) then return end

    ent.ClippyData = nil

    if ( table.HasValue( Clippy.Clips, ent ) ) then
        
        table.RemoveByValue( Clippy.Clips, ent )

    end

    Clippy.Log("unregistered all clips for ".. tostring(ent))

    -- remove all the undos for these clips if they exist
    if ( ent.ClippyUndoers != nil ) then

        Clippy.CleanupUndos( ent )
        
    end
    
    -- inform clients to remove all clips for this ent
    net.Start( "clippy_reset" )
        net.WriteEntity( ent )
    net.Broadcast()

    -- update duplicator info
    duplicator.ClearEntityModifier( ent, "clippy" )

end

-- Update a single clip
function Clippy.UpdateClip( ent, id, tbl )

    if ( !IsValid( ent ) ) then
        Clippy.Log("UpdateClip called for invalid entity")
        return
    end

    local clip = {
        Version = Clippy.Version,
        Ang = tbl.Ang,
        Distance = tbl.Distance,
        Inside = tbl.Inside
    }

    ent.ClippyData[ id ] = clip

    local struct = {
        EntIndex = ent:EntIndex(),
        Version = Clippy.Version,
        Ang = Clippy.AngleToString( clip.Ang ),
        Distance = Clippy.DistanceToString( clip.Distance ),
        Inside = (clip.Inside and 1 or 0)
    }

    net.Start( "clippy_update" )
        net.WriteUInt( id, 8 )
        net.WriteStructure( "clippy_clip", struct )
    net.Broadcast()

    duplicator.StoreEntityModifier( ent, "clippy", ent.ClippyData )

    Clippy.Log("updating clip ".. tostring(id) .." for ".. tostring(ent))

end

-- Send a single clip
function Clippy.SendClip( ent, pl, id )

    if ( !IsValid( ent ) ) then
        Clippy.Log("SendClip received invalid entity")
        return
    end

    local clip = ent.ClippyData[id]

    if ( clip != nil ) then
        
        local struct = {
            EntIndex = ent:EntIndex(),
            Version = Clippy.Version,
            Ang = Clippy.AngleToString( clip.Ang ),
            Distance = Clippy.DistanceToString( clip.Distance ),
            Inside = (clip.Inside and 1 or 0)
        }

        net.Start( "clippy_clip" )
        net.WriteStructure( "clippy_clip", struct )

        if IsValid( pl ) then

            Clippy.Log("sending ".. tostring(ent) .." clip ".. tostring(id) .." to ".. tostring(pl:Name()))

            net.Send( pl )

        else

            Clippy.Log("sending ".. tostring(ent) .." clip ".. tostring(id) .." to everyone")
            
            net.Broadcast()

        end

    end

end

-- Send all clips
function Clippy.SendClips( ent, pl )

    local clips = {}

    if ( IsValid( ent ) and ent.ClippyData ) then
        
        for _, clip in pairs( ent.ClippyData ) do

            table.insert( clips, {
                EntIndex = ent:EntIndex(),
                Version = Clippy.Version,
                Ang = Clippy.AngleToString( clip.Ang ),
                Distance = Clippy.DistanceToString( clip.Distance ),
                Inside = (clip.Inside and 1 or 0)
            } )

        end

    else

        for _, ent in pairs( Clippy.Clips ) do
            
            local entclips = ent.ClippyData

            if ( entclips != nil and #entclips > 0 ) then

                for _, clip in pairs( entclips ) do

                    table.insert( clips, {
                        EntIndex = ent:EntIndex(),
                        Version = Clippy.Version,
                        Ang = Clippy.AngleToString( clip.Ang ),
                        Distance = Clippy.DistanceToString( clip.Distance ),
                        Inside = (clip.Inside and 1 or 0)
                    } )

                end

            end

        end

    end

    local count = #clips
    if ( count <= 0 ) then return end

    net.Start( "clippy_clips" )
    net.WriteStructure( "clippy_clips", { Clips = clips } )

    if IsValid( pl ) then

        Clippy.Log("sending ".. tostring(count) .." clips to ".. tostring(pl:Name()))

        net.Send( pl )

    else
        
        Clippy.Log("sending ".. tostring(count) .." clips to everyone")

        net.Broadcast()

    end

end

concommand.Add( "clippy_load", function( pl, cmd, args )

    if ( !IsValid( pl ) ) then return end

    -- Send all available clips to the player
    Clippy.SendClips( nil, pl )

end )
