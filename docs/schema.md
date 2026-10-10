# Database Schema Explained

## dealerships

One row per dealership (car showroom). It has a status field:

- pending = waiting for admin approval
- approved = can use the platform
- suspended = blocked

## users

Every person who logs in — consumers, dealer owners, salespeople, and admins.
Connected to auth.users automatically when someone signs up.
The role field determines what they can do.
The dealership_id field is null for consumers and set for dealer staff.

## vehicles

One row per car listed by a dealer.
The status field can be available, reserved, sold, or inactive.
Only available vehicles are shown to customers.

## vehicle_images

Multiple photos per vehicle. is_primary marks the main thumbnail.

## leads

Created when a customer submits an inquiry or books a test drive.
The type field is either inquiry or test_drive.
This is what shows up in the dealer's lead inbox.

## notifications

Auto-created by the app logic whenever a new lead comes in.
This powers the real-time alert on the dealer dashboard.
