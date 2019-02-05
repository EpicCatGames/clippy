
AddCSLuaFile()
AddCSLuaFile("clippy/lib/sh_netstructures.lua")

include("clippy/lib/sh_netstructures.lua")

-- Setup network messages
net.RegisterStructure( "clippy_clip", {
    Ent = STRUCTURE_ENTITY,
    Version = STRUCTURE_INT8,
    Ang = STRUCTURE_STRING,
    Distance = STRUCTURE_STRING,
    Inside = STRUCTURE_BIT
} )

net.RegisterStructure( "clippy_clips", {
    Clips = { "clippy_clip" }
} )

if SERVER then

    util.AddNetworkString( "clippy_clip" )
    util.AddNetworkString( "clippy_clips" )
    util.AddNetworkString( "clippy_undo" )
    util.AddNetworkString( "clippy_reset" )
    util.AddNetworkString( "clippy_update" )

end

-- Setup clippy
Clippy = Clippy or { Version = 1, Debug = false }

-- Table that stores all of our entities with registered clips
Clippy.Clips = Clippy.Clips or { }

-- http://wiki.garrysmod.com/page/render/PushCustomClipPlane
Clippy.ServerMaxClips = 7

if CLIENT then
    
    Clippy.ClientMaxClips = (system.IsWindows() and 7 or 3)

end

function Clippy.Log( ... )

    if ( Clippy.Debug ) then
        
        local args = { ... }
        local str = "[clippy] "

        for _, s in pairs( args ) do

            str = str .. tostring( s )

        end

        print( str )

    end

end

function Clippy.ChatPrint( pl, str )

    if ( IsValid( pl ) ) then
        
        pl:ChatPrint( "[clippy] ".. tostring( str ) )

    end

end

if CLIENT then
    
    function Clippy.Notify( str, type, length )

        notification.AddLegacy( str, type, length )
        
        surface.PlaySound( "buttons/button15.wav" )

    end

end

-- Convert floats to strings to fix precision errors over the network
function Clippy.AngleToString( ang )

    return tostring( ang )

end

function Clippy.AngleFromString( str )

    local tbl = string.Explode( " ", string.Trim( str ) )

    return Angle( tonumber( tbl[1] ), tonumber( tbl[2] ), tonumber( tbl[3] ) )

end

function Clippy.DistanceToString( dist )

    return tostring( dist )

end

function Clippy.DistanceFromString( dist )

    return tonumber( dist )

end

concommand.Add( "clippy", function( pl, cmd, args )

    Clippy.Log("version ".. tostring( Clippy.Version ) .." loaded")

    if CLIENT then

        local osStr = (system.IsWindows() and "windows" or "linux/osx")

        Clippy.Log("max clips per prop for ".. osStr .." is ".. tostring(Clippy.ClientMaxClips))

    end

end )

if SERVER then

    AddCSLuaFile("clippy/cl_clippy.lua")

    include("clippy/sv_clippy.lua")

else

    include("clippy/cl_clippy.lua")

end

-- Shared hooks
hook.Add( "InitPostEntity", "ClippyInitPostEntity", function()

    local verStr = "version ".. tostring( Clippy.Version ) .." loaded"

    print("[clippy] ".. verStr)

    if CLIENT then

        -- Request clips from the server after loading in
        timer.Simple( 10, function()

            if ( IsValid( LocalPlayer() ) ) then

                Clippy.ChatPrint( LocalPlayer(), verStr )

                RunConsoleCommand( "clippy_load" )
                
            end
        
        end )

    else

        --[[
        -- This will stop the old VisClip from doing much, but it should be removed entirely from servers using Clippy
        if ( SendPropClip ) then

            SendPropClip = function() end

            Clippy.Log("removed visual clips SendPropClip function for compatibility, but you should remove visual clip from your server entirely if you use clippy.")
            
        end
        --]]

    end

end )
