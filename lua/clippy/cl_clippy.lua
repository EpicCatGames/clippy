
local render = render

-- Hashtable of entindex to clip table due to entities not being valid on the client until they are in PVS
Clippy.Queue = Clippy.Queue or { }
Clippy.Data = Clippy.Data or { }

Clippy.PreviewModel = Clippy.PreviewModel or ClientsideModel("error.mdl")
Clippy.Last = nil

Clippy.PreviewModel:SetNoDraw(true)

Clippy.PreviewAng = Angle( cvars.Number( "clippy_pitch", 0 ), cvars.Number( "clippy_yaw", 0 ), 0)
Clippy.PreviewDist = cvars.Number( "clippy_distance", 0 )

local mat = Matrix()
mat:SetScale( Vector() )

-- Listen for cvar changes for the preview mode
cvars.AddChangeCallback( "clippy_pitch", function (_, _, new) 

    Clippy.PreviewAng.p = tonumber( new )

end )

cvars.AddChangeCallback( "clippy_yaw", function (_, _, new) 

    Clippy.PreviewAng.y = tonumber( new )

end )

cvars.AddChangeCallback( "clippy_distance", function (_, _, new) 

    Clippy.PreviewDist = tonumber( new )

end )

cvars.AddChangeCallback( "clippy_editor_pitch", function(_, _, new)

    Clippy.PreviewAng.p = tonumber( new )

end )

cvars.AddChangeCallback( "clippy_editor_yaw", function(_, _, new)

    Clippy.PreviewAng.y = tonumber( new )
    
end )

cvars.AddChangeCallback( "clippy_editor_distance", function(_, _, new)

    Clippy.PreviewDist = tonumber( new )
    
end )

local function InCreatorMode()

    return IsValid( LocalPlayer() ) and IsValid( LocalPlayer():GetActiveWeapon() ) and LocalPlayer():GetActiveWeapon():GetClass() == "gmod_tool" and GetConVarString("gmod_toolmode") == "clippy"

end

local function InEditorMode()

    return IsValid( LocalPlayer() ) and IsValid( LocalPlayer():GetActiveWeapon() ) and LocalPlayer():GetActiveWeapon():GetClass() == "gmod_tool" and GetConVarString("gmod_toolmode") == "clippy_editor"

end

local function ClippyRenderOverride( ent )

    -- Draw clips
    local Clips = Clippy.Data[ ent:EntIndex() ] or { }

    if ( #Clips > 0 and ent.Clipped ) then
        
        local col = ent:GetColor()

        render.EnableClipping( true )
        render.SetColorModulation( col.r / 255, col.g / 255, col.b / 255 )
        render.SetBlend( col.a / 255 )

        -- last clip rendered determines the inside setting, no real way to do it otherwise
        local inside = false

        for i, clip in pairs( Clips ) do

            -- limit number of clips based on os maximum
            if ( i > Clippy.ClientMaxClips ) then continue end

            inside = clip.Inside

            local ang = clip.Ang
            local dist = clip.Distance
            local normal = ent:LocalToWorldAngles( ang ):Forward()

            render.PushCustomClipPlane( normal, (ent:LocalToWorld( ent:OBBCenter() ) + normal * dist):Dot( normal ) )

        end

        ent:DisableMatrix( "RenderMultiply" )

        ent:SetupBones()
        ent:DrawModel()

        if ( inside ) then
            
            render.CullMode( MATERIAL_CULLMODE_CW )
            ent:DrawModel()
            render.CullMode( MATERIAL_CULLMODE_CCW )

        end

        for i, _ in pairs( Clips ) do

            -- limit number of clips based on os maximum
            if ( i > Clippy.ClientMaxClips ) then continue end

            render.PopCustomClipPlane()

        end

        ent:EnableMatrix( "RenderMultiply", mat )

        render.SetBlend( 1 )
        render.SetColorModulation( 1, 1,  1 )
        render.EnableClipping( false )

    end

end

-- Preview clips
hook.Add( "PostDrawOpaqueRenderables", "ClippyPreviewClips", function()

    if ( !IsValid( LocalPlayer() ) ) then return end

    local ent = LocalPlayer():GetEyeTraceNoCursor().Entity
    local isClipping = InCreatorMode() or InEditorMode()

    if ( IsValid( ent ) and Clippy.Last == ent and isClipping ) then
        
        ent:EnableMatrix( "RenderMultiply", mat )

        ent.Clipped = false

    else

        if ( IsValid( Clippy.Last ) ) then
            
            Clippy.Last:DisableMatrix( "RenderMultiply" )
            Clippy.Last.Clipped = true

        end

        Clippy.Last = nil

    end

    if ( !IsValid( ent ) or !LocalPlayer():Alive() or ent:IsPlayer() or ent:IsWorld() ) then return end
    if ( !isClipping ) then return end
    
    Clippy.Last = ent

    if ( Clippy.PreviewModel:GetModel() != ent:GetModel() ) then
        
        Clippy.PreviewModel:SetModel( ent:GetModel() )

    end

    Clippy.PreviewModel:SetPos( ent:GetPos() )
    Clippy.PreviewModel:SetAngles( ent:GetAngles() )

    local pos = ent:LocalToWorld( ent:OBBCenter() )
    local normal = -ent:LocalToWorldAngles( Clippy.PreviewAng ):Forward()

    render.EnableClipping( true )

    render.SetColorModulation( 0, 1000, 0 )
    render.PushCustomClipPlane( -normal, -normal:Dot( pos - normal * Clippy.PreviewDist ) )
        Clippy.PreviewModel:DrawModel()
    render.PopCustomClipPlane()

    render.SetColorModulation( 1000, 0, 0 )
    render.PushCustomClipPlane( normal, normal:Dot( pos - normal * Clippy.PreviewDist ) )
        Clippy.PreviewModel:DrawModel()
    render.PopCustomClipPlane()

    render.SetColorModulation( 1, 1, 1 )

    render.EnableClipping( false )

end )

-- Editor tool support
local function RefreshEditorTool()

    if ( InEditorMode() ) then
        
        local editor = LocalPlayer():GetTool( "clippy_editor" )

        if ( editor ) then

            editor:RebuildControlPanel()

        end

    end

end

local function ClippyOnRemoved( ent )

    Clippy.Log("removing ".. tostring( table.Count( Clippy.Data[ ent:EntIndex() ] ) ) .." clips from the cache for ".. tostring( ent:EntIndex() ))

    Clippy.Data[ ent:EntIndex() ] = nil

    RefreshEditorTool()

end

local function SetupEnt( ent )

    if ( !IsValid( ent ) ) then
        Clippy.Log("SetupEnt called for invalid entity!")
        return
    end

    ent.Clipped = true
    ent.RenderOverride = ClippyRenderOverride
    ent:CallOnRemove( "ClippyOnRemoved", ClippyOnRemoved )

end

-- Networking clips
local function AddClip( clip )

    clip.Ang = Clippy.AngleFromString( clip.Ang )
    clip.Distance = Clippy.DistanceFromString( clip.Distance )
    clip.Inside = (clip.Inside > 0 and true or false)

    local ent = Entity( clip.EntIndex )

    if ( IsValid( ent ) ) then

        Clippy.Data[ clip.EntIndex ] = Clippy.Data[ clip.EntIndex ] or { }

        table.insert( Clippy.Data[ clip.EntIndex ], clip )

        if ( !ent.Clipped or ent.RenderOverride == nil ) then
            
            SetupEnt( ent )

        end

        Clippy.Log("clip added directly to cache for ".. tostring( clip.EntIndex ))

    elseif ( Clippy.Queue[ clip.EntIndex ] ) then

        table.insert( Clippy.Queue[ clip.EntIndex ], clip )

        Clippy.Log("clip added to queue for ".. tostring( clip.EntIndex ))

    else

        Clippy.Queue[ clip.EntIndex ] = { clip }

        Clippy.Log("clip added to new queue for ".. tostring( clip.EntIndex ))

    end
    
end

local function UpdateClip( id, clip )

    clip.Ang = Clippy.AngleFromString( clip.Ang )
    clip.Distance = Clippy.DistanceFromString( clip.Distance )
    clip.Inside = (clip.Inside > 0 and true or false)

    local ent = Entity( clip.EntIndex )

    if ( IsValid( ent ) ) then

        if ( Clippy.Data[ clip.EntIndex ] == nil ) then

            Clippy.Log("UpdateClip received ent not in cache yet, adding clip instead")

            AddClip( clip )
            return

        end

        if ( Clippy.Data[ clip.EntIndex ][ id ] == nil ) then

            Clippy.Log("UpdateClip received invalid clip id for ".. tostring( clip.EntIndex ) .." [".. tostring( id ) .."], skipping")
            return
        
        end

        Clippy.Data[ clip.EntIndex ][ id ] = clip

    elseif ( Clippy.Queue[ clip.EntIndex ] ) then

    else

    end

--    local ent = clip.Ent
--
--    if ( !IsValid( ent ) ) then
--        Clippy.Log("UpdateClip invalid ent received")
--        return
--    end
--
--    if ( ent.ClippyData[ id ] == nil ) then
--        Clippy.Log("UpdateClip invalid clip id received ".. tostring(id))
--        return
--    end
--
--    clip.Ang = Clippy.AngleFromString( clip.Ang )
--    clip.Distance = Clippy.DistanceFromString( clip.Distance )
--    clip.Inside = (clip.Inside > 0 and true or false)
--
--    Clippy.Log("updating ".. tostring( ent ) .." clip ".. tostring( id ))
--
--    ent.ClippyData[ id ] = clip
--
--    RefreshEditorTool()

end

net.Receive( "clippy_update", function()

    local id = net.ReadUInt( 8 )
    local clip = net.ReadStructure( "clippy_clip" )

    UpdateClip( id, clip )

end )

net.Receive( "clippy_clip", function()

    local clip = net.ReadStructure( "clippy_clip" )
    
    AddClip( clip )

end )

net.Receive( "clippy_clips", function( len )

    local tbl = net.ReadStructure( "clippy_clips" )
    local clips = tbl.Clips

    Clippy.Log("received ".. tostring( #clips ) .." clips to load from server [".. tostring( len / 1000 ) .."kb]")

    for _, clip in pairs( clips ) do
        
        AddClip( clip )

    end

    if ( IsValid( LocalPlayer() ) ) then

        Clippy.ChatPrint( LocalPlayer(), "loaded ".. tostring( #clips ) .." clips from the server [".. tostring( len / 1000 ) .."kb]" )
        
    end

end )

net.Receive( "clippy_undo", function()

--    local ent = net.ReadEntity()
--    local id = net.ReadUInt( 8 )
--
--    if ( IsValid( ent ) ) then
--
--        if ( ent.ClippyData != nil and ent.ClippyData[id] ) then
--            
--            table.remove( ent.ClippyData, id )
--
--            RefreshEditorTool()
--
--        end
--
--    end

end )

net.Receive( "clippy_reset", function()

--    local ent = net.ReadEntity()
--
--    if ( IsValid( ent ) ) then
--        
--        ent.RenderOverride = nil
--        ent.ClippyData = nil
--
--        ent:SetNoDraw( false )
--        ent:DisableMatrix( "RenderMultiply" )
--
--        RefreshEditorTool()
--
--    end

end )

-- Process the queue, applying the render override as the entities become valid and shifting the clips into the cache
hook.Add( "Think", "ClippyThink", function()

    for index, clips in pairs( Clippy.Queue ) do

        local ent = Entity( index )

        if ( IsValid( ent ) ) then

            Clippy.Data[ index ] = Clippy.Queue[ index ]
            Clippy.Queue[ index ] = nil

            SetupEnt( ent )

            Clippy.Log("applying renderoverride to ".. tostring( index ) .." and removing from the queue")
            Clippy.Log(tostring(table.Count( Clippy.Queue )) .. " ents remaining in queue")

        end

    end

end )
