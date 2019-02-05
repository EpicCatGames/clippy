
TOOL.Category = "Construction"
TOOL.Name = "#Clippy - Create"
TOOL.Command = nil

TOOL.ClientConVar["pitch"] = "0"
TOOL.ClientConVar["yaw"] = "0"
TOOL.ClientConVar["distance"] = "0"
TOOL.ClientConVar["inside"] = "0"

if CLIENT then

    language.Add( "tool.clippy.name", "Clippy - Create" )
    language.Add( "tool.clippy.desc", "Visual Clip Creator" )
    language.Add( "tool.clippy.0", "Primary: Create Clip, Reload: Remove all Clips" )

    function TOOL.BuildCPanel( p )

        p:AddControl( "Header", { Text = "#tool.clippy.name", Description = "#tool.clippy.desc" } )
        local pitch = p:AddControl( "Slider", { Label = "Pitch", Type = "float", Min = "-180", Max = "180", Command = "clippy_pitch" } )
        local yaw = p:AddControl( "Slider", { Label = "Yaw", Type = "float", Min = "-180", Max = "180", Command = "clippy_yaw" } )
        local distance = p:AddControl( "Slider", { Label = "Distance", Type = "float", Min = "-180", Max = "180", Command = "clippy_distance" } )
        p:AddControl( "Checkbox", { Label = "Render Inside", Description = "Whether or not the clip will render inside the prop", Command = "clippy_inside" } )
        p:AddControl( "Button", { Label = "Reset Settings", Command = "clippy_reset" } )

        pitch:SetDecimals( 3 )
        yaw:SetDecimals( 3 )
        distance:SetDecimals( 3 )

    end

    concommand.Add( "clippy_reset", function( pl, cmd, args )
    
        Clippy.Log("creator tool settings reset")

        RunConsoleCommand( "clippy_pitch", 0 )
        RunConsoleCommand( "clippy_yaw", 0 )
        RunConsoleCommand( "clippy_distance", 0 )
        RunConsoleCommand( "clippy_inside", 0 )

    end )

end

function TOOL:LeftClick( tr )

    if SERVER then

        local ent = tr.Entity
        local pl = self:GetOwner()

        if ( !IsValid( ent ) or ent:IsWorld() or ent:IsPlayer() ) then return false end

        if ( ent.ClippyData != nil and #ent.ClippyData > Clippy.ServerMaxClips ) then

            Clippy.ChatPrint( pl, "target prop has the maximum amount of clips allowed by the source engine" )
            return false
            
        end
        
        local pitch = self:GetClientNumber( "pitch" )
        local yaw = self:GetClientNumber( "yaw" )
        local distance = self:GetClientNumber( "distance" )
        local inside = self:GetClientNumber( "inside" )

        -- Register clip
        local clipId = Clippy.RegisterClip( ent, Angle( pitch, yaw, 0 ), distance, tobool( inside ) )

        -- Register undo
        if ( clipId != nil ) then
            
            Clippy.CreateUndo( ent, pl, clipId )

        end

    end

    return true

end

function TOOL:RightClick( tr )

    return true

end

function TOOL:Reload( tr )

    if SERVER then

        local ent = tr.Entity
        local pl = self:GetOwner()

        if ( !IsValid( ent ) or ent:IsWorld() or ent:IsPlayer() ) then return end

        -- Unregister all clips
        Clippy.UnregisterClips( ent )

    end

    return true

end
