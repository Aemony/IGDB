# IGDB PowerShell Module

This is a PowerShell module for interfacing with the IGDB API and its endpoints.
Refer to the [IGDB API docs](https://api-docs.igdb.com/) for the specifics of the API itself.

The module was created to assist me in performing various tasks for the [PCGamingWiki](https://www.pcgamingwiki.com/) (PCGW) community project.


## Installation

0. An Twitch Account with a registered developer application is required to connect to the API, see the [Account Creation](https://api-docs.igdb.com/#account-creation) chapter over on the IGDB API docs.

1. Download or clone the repository to a local folder called `IGDB`.

2. Launch a new PowerShell session and import the module by using `Import-Module <path-to-the-IGDB-folder>` (e.g. `Import-Module .\IGDB`)

   * Be sure to omit any trailing backslash in the path as otherwise the command will fail.

3. Connect to the IGDB API using one of these alternatives:

   * To establish a new connection: `Connect-IGDBSession`
   * To use/setup a persistent config: `Connect-IGDBSession -Persistent`
   * To disconnect from an active session, use `Disconnect-IGDBSession`

4. Once connected, see [examples](#examples) or use one of the supported [cmdlets](#cmdlets) to retrieve data.


## Cmdlets

* All cmdlets supports the same base parameters:
  * `-Where`
  * `-Fields` (defaults to "*" if empty)
  * `-OrderBy`
  * `-Offset`
  * `-Limit`

* Searchable endpoints also provide a `Find-` cmdlet:
  * `Find-IGDBCharacter`
  * `Find-IGDBCollection`
  * `Find-IGDBGame`
  * `Find-IGDBPlatform`
  * `Find-IGDBTheme`
  * `Search-IGDB` (searches all searchable endpoints)

* Refer to the [IGDB API docs](https://api-docs.igdb.com/) for the specifics of each endpoint.

| API Endpoint                         | PowerShell Cmdlets                      |
| ------------------------------------ | --------------------------------------- |
| age_rating_categories                | Get-IGDBAgeRatingCategory               |
| age_rating_content_description_types | Get-IGDBAgeRatingContentDescriptionType |
| age_rating_content_descriptions      | Get-IGDBAgeRatingContentDescription     |
| age_rating_content_descriptions_v2   | Get-IGDBAgeRatingContentDescriptionV2   |
| age_rating_organizations             | Get-IGDBAgeRatingOrganization           |
| age_ratings                          | Get-IGDBAgeRating                       |
| alternative_names                    | Get-IGDBAlternativeName                 |
| artwork_types                        | Get-IGDBArtworkType                     |
| artworks                             | Get-IGDBArtwork                         |
| characters                           | Get-IGDBCharacter, Find-IGDBCharacter   |
| character_genders                    | Get-IGDBCharacterGender                 |
| character_mug_shots                  | Get-IGDBCharacterMugShot                |
| character_species                    | Get-IGDBCharacterSpecies                |
| collections                          | Get-IGDBCollection, Find-IGDBCollection |
| collection_membership_types          | Get-IGDBCollectionMembershipType        |
| collection_memberships               | Get-IGDBCollectionMembership            |
| collection_relation_types            | Get-IGDBCollectionRelationType          |
| collection_relations                 | Get-IGDBCollectionRelation              |
| collection_types                     | Get-IGDBCollectionType                  |
| companies                            | Get-IGDBCompany                         |
| company_logos                        | Get-IGDBCompanyLogo                     |
| company_statuses                     | Get-IGDBCompanyStatus                   |
| company_websites                     | Get-IGDBCompanyWebsite                  |
| covers                               | Get-IGDBCover                           |
| date_formats                         | Get-IGDBDateFormat                      |
| events                               | Get-IGDBEvent                           |
| event_logos                          | Get-IGDBEventLogo                       |
| event_networks                       | Get-IGDBEventNetwork                    |
| external_game_sources                | Get-IGDBExternalGameSource              |
| external_games                       | Get-IGDBExternalGame                    |
| franchises                           | Get-IGDBFranchise                       |
| games                                | Get-IGDBGame, Find-IGDBGame             |
| games/count                          | Get-IGDBGameCount                       |
| game_engine_logos                    | Get-IGDBGameEngineLogo                  |
| game_engines                         | Get-IGDBGameEngine                      |
| game_localizations                   | Get-IGDBGameLocalization                |
| game_modes                           | Get-IGDBGameMode                        |
| game_release_formats                 | Get-IGDBGameReleaseFormat               |
| game_statuses                        | Get-IGDBGameStatus                      |
| game_time_to_beats                   | Get-IGDBGameTimeToBeat                  |
| game_types                           | Get-IGDBGameType                        |
| game_version_feature_values          | Get-IGDBGameVersionFeatureValue         |
| game_version_features                | Get-IGDBGameVersionFeature              |
| game_versions                        | Get-IGDBGameVersion                     |
| game_videos                          | Get-IGDBGameVideo                       |
| genres                               | Get-IGDBGenre                           |
| involved_companies                   | Get-IGDBInvolvedCompany                 |
| keywords                             | Get-IGDBKeyword                         |
| languages                            | Get-IGDBLanguage                        |
| language_support_types               | Get-IGDBLanguageSupportType             |
| language_supports                    | Get-IGDBLanguageSupport                 |
| multiplayer_modes                    | Get-IGDBMultiplayerMode                 |
| network_types                        | Get-IGDBNetworkType                     |
| platforms                            | Get-IGDBPlatform, Find-IGDBPlatform     |
| platform_families                    | Get-IGDBPlatformFamily                  |
| platform_logos                       | Get-IGDBPlatformLogo                    |
| platform_types                       | Get-IGDBPlatformType                    |
| platform_version_companies           | Get-IGDBPlatformVersionCompany          |
| platform_version_release_dates       | Get-IGDBPlatformVersionReleaseDate      |
| platform_versions                    | Get-IGDBPlatformVersion                 |
| platform_websites                    | Get-IGDBPlatformWebsite                 |
| player_perspectives                  | Get-IGDBPlayerPerspective               |
| popularity_primitives                | Get-IGDBPopularityPrimitives            |
| popularity_types                     | Get-IGDBPopularityType                  |
| regions                              | Get-IGDBRegion                          |
| release_dates                        | Get-IGDBReleaseDate                     |
| release_date_regions                 | Get-IGDBReleaseDateRegion               |
| release_date_statuses                | Get-IGDBReleaseDateStatus               |
| screenshots                          | Get-IGDBScreenshot                      |
| search                               | Search-IGDB                             |
| themes                               | Get-IGDBTheme, Find-IGDBTheme           |
| websites                             | Get-IGDBWebsite                         |
| website_types                        | Get-IGDBWebsiteType                     |


## Examples

Retrieve the IGDB ID of a game using its specific name:
```powershell
Get-IGDBGame -Where 'name = "Half-Life 2"' -Fields 'id'
```

```
id   : 233
name : Half-Life 2
```

Retrieve the cover of a game using its IGDB ID:
```powershell
Get-IGDBCover -Where 'game = 233'
```

```txt
id            : 77288
alpha_channel : False
animated      : False
game          : 233
height        : 1008
image_id      : co1nmw
url           : //images.igdb.com/igdb/image/upload/t_thumb/co1nmw.jpg
width         : 756
checksum      : 31724ab3-ac41-fb4a-1b30-4f3d0d690928
```

Retrieve the External Game Source ID for Steam: 
```powershell
Get-IGDBExternalGameSource -Where 'name = "Steam"' -Fields 'id'
```

```txt
id         : 1
name       : Steam
created_at : 1612529709
updated_at : 1695207341
checksum   : 123e4567-e89b-12d3-a456-426614174000
```

Retrieve the external game details of a game using its Steam App ID:
```powershell
Get-IGDBExternalGame -Where 'external_game_source = 1 & uid = "220"'
```

```txt
id                   : 15164
category             : 1
created_at           : 1494751166
game                 : 233
name                 : Half-Life 2
uid                  : 220
updated_at           : 1746150583
url                  : https://store.steampowered.com/app/220
checksum             : d36324c5-9dd7-08a0-ba42-f208cb2ee59b
external_game_source : 1
```

Search IGDB for all Mirror's Edge games and list their names:
```powershell
Find-IGDBGame "Mirror's Edge" -Fields 'name'
```

```txt
    id name
    -- ----
 77348 Mirror's Edge
  1051 Mirror's Edge
  2112 Mirror's Edge Catalyst
 77347 Mirror's Edge 2D
341267 The Mirror's Edge
344631 Mirror's Edge: Pure Time Trials
 41618 Mirror's Edge Catalyst: Collector's Edition
```

Search IGDB for all items related to Michael Jackson and list their name and internal + game identifiers:
```powershell
Search-IGDB "Michael Jackson" -Fields 'name, id, game'
```

```txt
      id   game name
      --   ---- ----
22562973 320979 Michael Jackson Baby Drop
20779023 301726 Michael Jackson The Experience
20779022 301727 Michael Jackson The Experience
18148227 262508 Michael Jackson's Moonwalker
17501239 253617 Michael Jackson's Moonwalker
15344088 233982 Michael Jackson in Scramble Training
 4043565        Michael Jackson (I)
 1317302        Michael Jackson's Moonwalker
 1280845        Michael Jackson
  141810  18139 Michael Jackson's Moonwalker
```


## Third-party code

Third-party code is noted in the source code, with the appropriate license links.
This is a short overview of the code being used:

* https://stackoverflow.com/a/57045268
* https://github.com/abgox/ConvertFrom-JsonToHashtable
