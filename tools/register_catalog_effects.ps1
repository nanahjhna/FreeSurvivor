$ErrorActionPreference = "Stop"
$catalogPath = Join-Path $PSScriptRoot "..\data\skill_catalog.json"
$catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
$readyCount = 0

function Set-CatalogProperty($Object, [string]$Name, $Value) {
	$Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value -Force
}

foreach ($skill in $catalog.skills) {
	$description = [string]$skill.reference_description
	$type = ""
	$complexEffect = $description -match "둔화|기절|속박|침묵|공포|도발|공중으로|밀쳐|끌어|출혈|중첩|변신|설치|소환|보호막|피해 감소|방어력|마법 저항|공격 속도|이동 속도|재사용 대기시간|공격을 회피|무적|추가 사용"

	if ($skill.key -eq "P" -and $description -match "피해를 받지 않으면" -and $description -match "체력을 회복|회복합니다") {
		$type = "passive"
	} elseif ($skill.key -ne "P" -and -not $complexEffect -and $description -match "체력을 회복|회복합니다|치유합니다" -and $description -match "자신|자기|체력을 회복") {
		$type = "heal"
	} elseif (-not $complexEffect -and $description -match "회전|주변 적에게 물리 피해|주위 적에게 피해" -and $description -match "피해") {
		$type = "spin"
	} elseif (-not $complexEffect -and $description -match "폭발|범위 안의 적|주변의 적에게 피해" -and $description -match "피해") {
		$type = "burst"
	} elseif (-not $complexEffect -and $description -match "발사|던져|날려|투척|칼날|화살|창을 던져" -and $description -match "피해") {
		$type = "wave"
	}

	Set-CatalogProperty $skill "game_name" ([string]$skill.reference_name)
	Set-CatalogProperty $skill "game_ready" $false
	Set-CatalogProperty $skill "game_support_status" "unimplemented"
	Set-CatalogProperty $skill "mana_cost" 0
	if (-not $type) {
		continue
	}

	$readyCount++
	$scene = ""
	$bonus = "physical"
	$visualColor = "#ffc247"
	$range = 14.0
	$damageRatio = 1.4
	$cooldown = 7.0
	if ($description -match "마법 피해|마법|마력|주문|불꽃|화염|번개|얼음") {
		$bonus = "magic"
		$visualColor = "#75aaff"
	}

	switch ($type) {
		"passive" {
			Set-CatalogProperty $skill "passive_handler" "regen_after_damage"
			Set-CatalogProperty $skill "regen_delay" 4.0
			Set-CatalogProperty $skill "hp_regen_ratio" 0.01
			$range = 0.0
			$damageRatio = 0.0
			$cooldown = 0.0
		}
		"heal" {
			Set-CatalogProperty $skill "heal_ratio" 0.2
			$bonus = "healing"
			$visualColor = "#52e6a0"
			$range = 0.0
			$damageRatio = 0.0
			$cooldown = 25.0
		}
		"spin" {
			$scene = "res://scenes/skills/spin_attack.tscn"
			$bonus = "area"
			$range = 5.0
			$cooldown = 9.0
		}
		"burst" {
			$scene = "res://scenes/skills/explosion.tscn"
			$bonus = "area"
			$range = 10.0
			$damageRatio = 2.4
			$cooldown = 18.0
		}
		"wave" {
			$scene = "res://scenes/skills/sword_wave.tscn"
		}
	}

	Set-CatalogProperty $skill "cast_type" $type
	Set-CatalogProperty $skill "effect_scene" $scene
	Set-CatalogProperty $skill "bonus_type" $bonus
	Set-CatalogProperty $skill "visual_color" $visualColor
	Set-CatalogProperty $skill "base_cd" $cooldown
	Set-CatalogProperty $skill "base_dmg_ratio" $damageRatio
	Set-CatalogProperty $skill "cd_step" 0.0
	Set-CatalogProperty $skill "dmg_step" 0.0
	Set-CatalogProperty $skill "cost_base" $(if ($skill.key -eq "R") { 400 } else { 180 })
	Set-CatalogProperty $skill "range" $range
	Set-CatalogProperty $skill "unlock_level" $(if ($skill.key -eq "R") { 8 } else { 1 })
	Set-CatalogProperty $skill "game_support_status" "generic_effect_ready"
	Set-CatalogProperty $skill "game_ready" $true
}

$catalog.count = @($catalog.skills).Count
$json = ConvertTo-Json -InputObject $catalog -Depth 20
[System.IO.File]::WriteAllText($catalogPath, $json, [System.Text.UTF8Encoding]::new($false))
Write-Output "Manager-ready skills: $readyCount / $($catalog.count)"
