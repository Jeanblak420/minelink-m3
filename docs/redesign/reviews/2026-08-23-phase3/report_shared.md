# Shared surfaces — reviewer report (condensed, 2026-08-23). Task 6 of Phase 3. Verify each before fixing.

No-drift: /login (drop), user-preferences (console), chat-connections (console), log fuel/cost dialogs, add document dialog.
F1. auth_shell.dart:75-83 title headlineSmall w800 sans ("Forgot your password?","Create a new password") → editorialLarge · c1.
F2. auth_shell.dart:118-246 `_AuthRail`/`_RailStat` re-implements MlBrandPanel (minelink_signin_brand.dart:28) in sans → mount MlBrandPanel · c1/§5.3.
F3. reset_password_screen.dart:199 'Request New Reset Link' · c3.
F4. whatsapp_otp_screen.dart:105,123-129 titleMedium w800 + bare AppBar; mandatory_password_change_screen.dart:119-124 titleLarge w800 → AuthShell · c1.
F5. profile_setup_screen.dart:199-203 `40%` headlineMedium sans; no MlPageHeader (:28-60); profile_screen.dart:1076-1079 same % · c1/§5.4.
F6. profile_setup_screen.dart:298-302 MlButton.primary on every row incl. COMPLETE → tonal for complete · c5.
F7. profile_screen.dart:511,633,786 'Company Information','CEO Information','Personal Information' · c3.
F8. profile_screen.dart:527,544,562,610,662,678,716,828,989 'Company Name','WhatsApp Number','Organization Type','CEO First Name','CEO Last Name','Update Profile'×2,'Owner contact No.' · c3.
F9. token_access_details.dart:118,122,126,138 'Token Assigned/Lifetime/Expiration/Expires in' (also organization_detail_screen.dart:1146-1147) · c3.
F10. company_token_requests_panel.dart:15-25,60-69 bare Card titleMedium bold sizes to content (host profile_screen.dart:462-463) → MlCard+MlSectionTitle+width · c1+4.
F11. company_locations_section.dart:44-49 'Locations'; deactivate_account_card.dart:189-197 'Deactivate account' titleMedium w800 sans → MlSectionTitle · c1.
F12. company_locations_section.dart:82-86 Add location Align centerLeft on phone → right · c2.
F13. account_security_screen.dart:30-43 header full width vs :57-73 cards centred 560 → header inside the column · c4.
F14. redesign_renders_test.dart:4408-4420 appearance light golden shows Dark selected (themeModeProvider not overridden; theme_mode_provider.dart:11) · c6.
F15. appearance_theme_screen.dart:185-190 `_SectionCard` titleMedium w800 headings "Colour mode","Mine theme","Density" → MlSectionTitle · c1.
F16. messages_screen.dart:729-816 `_MessageBubble` ignores fileUrl/fileName/replyToId → empty bubble, no quotes; composer :817 no attach · c6.
F17. three bubble vocabularies messages_screen.dart:729-862 / chat_widget.dart:967 bodyLarge / chat_dock bubble · §5.
F18. messages_screen.dart:199 "Chats/People" vs chat_dock.dart:1019 "Conversations/Contacts" · c3.
F19. chat_widget.dart:745-757 attachment FutureBuilder over memo attachment_url.dart:64-77 → spinner vs icon nondeterministic across goldens · c9.
F20. chat_dock.dart:2567 / chat_widget.dart:1057 '📎 $name' and reaction emoji render tofu in goldens · c9 → WidgetSpan icon.
F21. chat_dock.dart:2240-2267 `_ConvTick` delivered ticks red; :2216 unread separator red; offline dot red; tokens ml_chat_palettes.dart:359-362 · c5.
F22. chat_dock.dart:1898 and :2326 two typing indicators · minor.
F23. notification_model.dart:66-110 14/21 NotificationType.label Title Case · c3.
F24. notification_screen.dart:308 'Clear All'; notification_management_screen.dart:154 'About Notification Management'; welcome_notification.dart:110 'Get Started'; chat_screen.dart:568 'Copy Text'; chat_dock.dart:4214 'Messages Settings' · c3.
F25. buyer_loads_value_screen.dart:686-699 invoice date as OutlinedButton vs InputDecorator pattern fuel_costs_screen.dart:700-716 · §5.
F26. codes in sans in dialog titles: mine_quality_screen.dart:303; quality_cert_dialog.dart:160-172; buyer_loads_value_screen.dart:637-646; waybill_modal.dart:156,178-182; load_controller_screen.dart:55 via ml_overlays.dart:187-193 · §5.3 minor.
F27. ml_overlays.dart:185-193 slide-over title maxLines 1 ellipsis → 2 · c7.
F28. org_group_dialog.dart:20-22 claims own company not listed vs :79,121-140 no filter → filter c.id != myCompanyId · c6.
F29. vehicle_details_fields.dart:262-266 scheme.tertiary (violet) well decorative; `_SectionHeader` :393-420 titleSmall w700 · c5/c1.
F30. fleet_management_screen.dart:91 'Add Vehicle' tooltip (render test finds by tooltip redesign_renders_test.dart:4847) · c3.

NOT drift: login gold/stats/uppercase labels; dialog titles sans (dialogTheme app_theme.dart:126 — one edit if wanted); MlButton.go; dock Nord palette (client call); console amber accent; MlSectionTitle stacking; DB-authored notification titles; plate in body prose; document names; notifications header wrap; EXTREME/HIGH; IMMEDIATELY paragraph; 70% orange; chat panel rows/mention token.
Missing: OTP/mandatory desktop; forgot/reset success; employee profile variant; light for profile/security/notifications/messages/chat; signature pad/prompt; messages blocked/ended banners (chat-states-dark.png reference exists!); dock settings/contacts/profile panel; confirm dialogs; no tutorial overlay.
