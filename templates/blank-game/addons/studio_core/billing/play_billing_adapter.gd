class_name StudioPlayBillingAdapter
extends StudioBillingAdapter
## PLACEHOLDER. Not wired to a real SDK yet.
##
## Intended backend: the official godot-sdk-integrations "godot-google-play-billing" plugin
## (see docs/monetization.md). It requires the Android plugin in the export and testing with
## a Play Console license tester, which needs the developer's machine and account.
## Until then this adapter reports the store as unavailable, so purchases are disabled.


func name() -> String:
	return "play_billing"
