# Super Admin & Organization Management - Implementation Task List

## 1. Test Accounts & Data Migration

- [ ] Parse and read all companies from `assets/work_flow_test_accounts.md`.
- [ ] Activate all listed companies ensuring they have valid login details.
- [ ] Generate and assign active tokens for each of these test companies.
- [ ] Correctly link all users associated with these companies to their respective company accounts.
- [ ] Ensure all users have the correct user account types.
- [ ] Ensure companies are systematically linked to the "Super_Global_Serial-Admin_Account-type" so they appear under the user's linked company view.
- [ ] Verify that each company's allocated seats matches or exceeds their current active user count.

## 2. Registration Flow & Company Workflows

- [ ] Update the complete user account registration flow to reflect new company linking logic.
- [ ] Update the complete company account registration flow.
- [ ] Implement a feature allowing companies to directly register a user's account via the company dashboard.

## 3. Seat Management & Anti-Abuse System

- [ ] Implement the ability for a company to add unlimited users (both active and inactive) to their account, exceeding their paid/allocated seats.
- [ ] Restrict active access ONLY to users who have an assigned "active seat" (e.g., if a company has 10 seats and 20 users, only 10 users get active access).
- [ ] Display an automated notification/system message prompting the company to upgrade seats when their total user count exceeds active seats.
- [ ] Implement seat assignment UI for companies to manage which users occupy the available seats.
- [ ] Implement the Anti-Abuse restriction guard:
  - [ ] A company can only reassign (remove from one user and assign to another) a maximum of 2 seats every 30 days.
  - [ ] Ensure these reassignments do not accrue or roll over like credits (hard limit of 2 per 30 days).

## 4. Token UI & Management (Company & Super Admin)

- [ ] Add the "date token was assigned" to the relevant token/company screens.
- [ ] Implement a real-time, live countdown timer for token expiry (format: `days-hours-minutes-seconds`).
- [ ] Display this live countdown in the company's account profile.
- [ ] Create a detailed token information view for the `superGlobalSerialAdminMain` account under each organization's specific tab.
- [ ] Include the live countdown and token history download option in both the Super Admin view and the respective Company's view.
- [ ] Ensure token information explicitly lists the details of seats linked/assigned to that token.

## 5. Seat Serial Generation & Role-Binding System

- [ ] Implement a fully customizable UI for companies to request tokens, seat upgrades, specific valid periods, and additional user seats.
- [ ] Bind each requested seat to a specific "employee role type" relevant to the company's organization type (since different org types have different roles).
- [ ] Restrict seat reassignment across different roles (e.g., a "security" seat cannot be reassigned to an "admin" user without an official seat upgrade request).
- [ ] Implement the Seat Serial Number Generator:
  - [ ] Minimum of 15 characters (numbers, uppercase, lowercase, symbols).
  - [ ] Ensure the last 3 characters are always identical for the same role type (e.g., all security seats end in the same 3 characters).
- [ ] Restrict visibility of seat serial numbers and sensitive seat/token info strictly to the `superGlobalSerialAdminMain` and the respective Company Owner accounts via dedicated UI tabs.

## 6. Super Admin Specific UI Enhancements

- [ ] In the linked company users tab within the Super Admin dashboard, implement detailed, clickable user profiles that display full information to the `superGlobalSerialAdminMain`.
