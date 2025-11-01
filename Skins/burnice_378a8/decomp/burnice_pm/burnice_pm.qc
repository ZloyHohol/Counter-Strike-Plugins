
$ModelName "player/likeaworm/burnice/burnice_pm.mdl"

$BodyGroup "Survivor"
{
	studio "burnice_pm_Burnice_Face.smd"
}
$BodyGroup "body1"
{
	studio "burnice_pm_Burnice_Body_1.smd"
}
$BodyGroup "body2"
{
	studio "burnice_pm_Burnice_Body_2.smd"
}

$Include "burnice_pm_lod.qci"

$SurfaceProp "flesh"

$Contents "solid"

$IllumPosition -3.106 -0.473 35.538

$MaxEyeDeflection 30

$ForcePhonemeCrossFade

$Opaque

$CDMaterials "models\player\likeaworm\burnice\"

$TextureGroup "skinfamilies"
{
	{ "MAT_Burnice_Face_UI" "MAT_Burnice_Eye_UI" "MAT_Burnice_Eyebrows_UI" "MAT_Burnice_Body_1_UI" "MAT_Burnice_Body_T_UI" "MAT_Burnice_Hair_T_UI" "MAT_Burnice_Body_2_UI" }
}

// This list shows the VMT file names used in the SMD files.
// "MAT_Burnice_Face_UI.vmt"
// "MAT_Burnice_Eye_UI.vmt"
// "MAT_Burnice_Eyebrows_UI.vmt"
// "MAT_Burnice_Body_1_UI.vmt"
// "MAT_Burnice_Body_T_UI.vmt"
// "MAT_Burnice_Hair_T_UI.vmt"
// "MAT_Burnice_Body_2_UI.vmt"

$Attachment "forward" "ValveBiped.forward" 0 0 0 rotate 0 0 0
$Attachment "grenade0" "ValveBiped.Bip01_Spine" 6.93 -0.7 1.89 rotate 58 97 89
$Attachment "grenade1" "ValveBiped.Bip01_Spine" 6.85 -0.22 2.85 rotate 9 100 91
$Attachment "grenade2" "ValveBiped.Bip01_Spine" 5.98 -1.74 -2.35 rotate -56 108 82
$Attachment "grenade3" "ValveBiped.Bip01_Spine" 4.17 2.72 -5.09 rotate -57 98 93
$Attachment "pistol" "ValveBiped.Bip01_R_Thigh" 5.61 4.11 -4.22 rotate 0 -4 87
$Attachment "primary" "ValveBiped.Bip01_Spine2" 12.29 -5.89 2.07 rotate -8 178 180
$Attachment "eholster" "ValveBiped.Bip01_L_Thigh" 9.66 -2.74 2.6 rotate 0 -91 95
$Attachment "c4" "ValveBiped.Bip01_Spine2" 11.02 -5.63 -2.91 rotate -47 75 16
$Attachment "lfoot" "ValveBiped.Bip01_L_Foot" 0 5.3 0 rotate 0 0 0
$Attachment "rfoot" "ValveBiped.Bip01_R_Foot" 0 5.3 0 rotate 0 0 0
$Attachment "muzzle_flash" "ValveBiped.Bip01_L_Hand" 0 0 0 rotate 0 0 0

// $Include "burnice_pm_box.qci"

$Include "burnice_pm_bone.qci"

$Include "burnice_pm_animation.qci"

$Include "burnice_pm_collision.qci"
