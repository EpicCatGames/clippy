
TOOL.Category = "Construction"
TOOL.Name = "#Clippy - Edit"
TOOL.Command = nil

TOOL.ClientConVar["pitch"] = "0"
TOOL.ClientConVar["yaw"] = "0"
TOOL.ClientConVar["distance"] = "1"
TOOL.ClientConVar["inside"] = "0"
TOOL.ClientConVar["clip"] = "1"

if CLIENT then

    Clippy.Panels = Clippy.Panels or { Settings = {} }
    Clippy.Editor = Clippy.Editor or { }

    language.Add( "tool.clippy_editor.name", "Clippy - Edit" )
    language.Add( "tool.clippy_editor.desc", "Visual Clip Editor" )
    language.Add( "tool.clippy_editor.0", "Primary: Select Entity, Reload: Remove Selected Clip, Right Click: Update Selected Clip" )

    local border = 0
    local border_w = 8
    local matHover = Material( "gui/ps_hover.png", "nocull" )
    local boxHover = GWEN.CreateTextureBorder( border, border, 64 - border * 2, 64 - border * 2, border_w, border_w, border_w, border_w, matHover )

    function TOOL.BuildCPanel( p )

        p:AddControl( "Header", { Text = "#tool.clippy_editor.name", Description = "#tool.clippy_editor.desc" } )

        if ( IsValid( Clippy.Editor.SelectedEnt ) and Clippy.Data[Clippy.Editor.SelectedEnt:EntIndex()] != nil and #Clippy.Data[Clippy.Editor.SelectedEnt:EntIndex()] > 0 ) then

            -- Clip list
            local Label = vgui.Create( "DLabel", p )
            Label:SetText( "Visual Clips" )
            Label:SetTextColor( Color( 0, 0, 0 ) )

            p:AddPanel( Label )

            Clippy.Panels.Scroll = vgui.Create( "DScrollPanel", p )
            Clippy.Panels.Scroll:Dock( FILL )
            Clippy.Panels.Scroll:SetHeight( 524 )

            Clippy.Panels.List = vgui.Create( "DIconLayout", Clippy.Panels.Scroll )
            Clippy.Panels.List:Dock( FILL )
            Clippy.Panels.List:SetSpaceY( 1 )
            Clippy.Panels.List:SetSpaceX( 1 )

            -- Populate clips
            if ( IsValid( Clippy.Editor.SelectedEnt ) ) then

                local ent = Clippy.Editor.SelectedEnt
                local clips = Clippy.Data[Clippy.Editor.SelectedEnt:EntIndex()] or { }

                for id, clip in pairs( clips ) do
                    
                    local panel = Clippy.Panels.List:Add( "DModelPanel" )
                    panel:SetSize( 128, 128 )
                    panel:SetModel( ent:GetModel() )
                    panel:SetTooltip( "Clip ".. tostring( id ) )
                    panel.LayoutEntity = function() end
                    panel.clipid = id

                    local panelEnt = panel:GetEntity()
                    local pos = panelEnt:GetPos()
                    local ang = panelEnt:GetAngles()

                    local tab = PositionSpawnIcon( panelEnt, pos, true )

                    panelEnt:SetAngles( ang )

                    if ( tab ) then

                        panel:SetCamPos( tab.origin )
                        panel:SetFOV( tab.fov )
                        panel:SetLookAng( tab.angles )

                    end

                    panel.DrawModel = function()

                        local pos = panelEnt:LocalToWorld( panelEnt:OBBCenter() )
                        local normal = -panelEnt:LocalToWorldAngles( clip.Ang ):Forward()

                        render.EnableClipping( true )

                        render.SetColorModulation( 0, 1000, 0 )
                        render.PushCustomClipPlane( -normal, -normal:Dot( pos - normal * clip.Distance ) )
                            panelEnt:DrawModel()
                        render.PopCustomClipPlane()

                        render.SetColorModulation( 1000, 0, 0 )
                        render.PushCustomClipPlane( normal, normal:Dot( pos - normal * clip.Distance ) )
                            panelEnt:DrawModel()
                        render.PopCustomClipPlane()

                        render.SetColorModulation( 1, 1, 1 )

                        render.EnableClipping( false )

                    end

                    panel.PaintOver = function( p, w, h )

                        if ( cvars.Number( "clippy_editor_clip", 0 ) == panel.clipid ) then
                            
                            boxHover( 0, 0, w, h, color_white )

                        end

                    end

                    panel.DoClick = function()

                        RunConsoleCommand( "clippy_editor_clip", id )
                        RunConsoleCommand( "clippy_editor_pitch", clip.Ang.p )
                        RunConsoleCommand( "clippy_editor_yaw", clip.Ang.y )
                        RunConsoleCommand( "clippy_editor_distance", clip.Distance )
                        RunConsoleCommand( "clippy_editor_inside", clip.Inside )

                    end

                    -- select last clip automatically and update our preview settings
                    if ( cvars.Number( "clippy_editor_clip " ) == panel.clipid ) then

                        panel.DoClick()

                    end

                end

            end

            p:AddPanel( Clippy.Panels.Scroll )
            
            -- Clip Settings
            Clippy.Panels.Settings.Pitch = p:AddControl( "Slider", { Label = "Pitch", Type = "float", Min = "-180", Max = "180", Command = "clippy_editor_pitch" } )
            Clippy.Panels.Settings.Yaw = p:AddControl( "Slider", { Label = "Yaw", Type = "float", Min = "-180", Max = "180", Command = "clippy_editor_yaw" } )
            Clippy.Panels.Settings.Distance = p:AddControl( "Slider", { Label = "Distance", Type = "float", Min = "-180", Max = "180", Command = "clippy_editor_distance" } )
            Clippy.Panels.Settings.Inside = p:AddControl( "Checkbox", { Label = "Render Inside", Description = "Whether or not the clip will render inside the prop", Command = "clippy_editor_inside" } )

            Clippy.Panels.Settings.Pitch:SetDecimals( 3 )
            Clippy.Panels.Settings.Yaw:SetDecimals( 3 )
            Clippy.Panels.Settings.Distance:SetDecimals( 3 )

        else
            
            local Label = vgui.Create( "DLabel", p )
            Label:SetText( "No valid entity selected" )
            Label:SetTextColor( Color( 100, 0, 0 ) )

            p:AddPanel( Label )

        end

    end

end

function TOOL:Deploy()

    if CLIENT then
        
        self:RebuildControlPanel()

    end

end

function TOOL:RebuildControlPanel()

    local CPanel = controlpanel.Get( "clippy_editor" )
    if ( CPanel ) then
        
        CPanel:ClearControls()
        self.BuildCPanel( CPanel )

    end

end

function TOOL:LeftClick( tr )

    local ent = tr.Entity
    local pl = self:GetOwner()

    if ( !IsValid( ent ) or ent:IsWorld() or ent:IsPlayer() ) then return end

    if CLIENT then

        Clippy.Editor.SelectedEnt = ent

        self:RebuildControlPanel()

    else

        pl.ClippyEditorEnt = ent

        Clippy.Log("player selected ".. tostring(pl.ClippyEditorEnt))

    end

    return true

end

function TOOL:RightClick( tr )

    if SERVER then

        local pl = self:GetOwner()
        local ent = pl.ClippyEditorEnt

        if ( !IsValid( ent ) or ent:IsWorld() or ent:IsPlayer() ) then return end
        
        local id = self:GetClientNumber( "clip" )
        local pitch = self:GetClientNumber( "pitch" )
        local yaw = self:GetClientNumber( "yaw" )
        local distance = self:GetClientNumber( "distance" )
        local inside = self:GetClientNumber( "inside" )

        local tbl = {
            Ang = Angle( pitch, yaw, 0 ),
            Distance = distance,
            Inside = tobool( inside )
        }

        Clippy.UpdateClip( ent, id, tbl )

    end

    return true

end

function TOOL:Reload( tr )

    if SERVER then

        local pl = self:GetOwner()
        local ent = pl.ClippyEditorEnt

        if ( !IsValid( ent ) or ent:IsWorld() or ent:IsPlayer() ) then return end

        local id = self:GetClientNumber( "clip" )

        if ( ent.ClippyData[id] != nil ) then
            
            Clippy.UnregisterClip( {}, ent, id )

        end

    end

    return true

end
