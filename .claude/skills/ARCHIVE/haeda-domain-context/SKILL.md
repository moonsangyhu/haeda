---
name: haeda-domain-context
description: Haeda project product concepts, terminology, core flows, season icons, and MVP scope summary
---

# Haeda Domain Context

## Product Concept

Collaborative challenge app where seasonal icons are completed only when all participants verify.
Core motivation: "Let's build a beautiful calendar together" -> natural mutual encouragement.

## Terminology

| Korean | English | Description |
|--------|---------|-------------|
| Challenge | Challenge | Core unit of the app. Creation, participation, verification, comments, and calendar all happen within a challenge |
| Verification | Verification | Photo (optional/required) + diary text submission |
| All-verified | DayCompletion | All challenge participants verified on that date |
| Season icon | season_icon_type | Seasonal icon displayed on calendar when all-verified |
| Member | ChallengeMember | User participating in a challenge |
| Achievement rate | achievement_rate | (actual verifications / expected verifications) x 100 |
| Invite code | invite_code | 8-character code for challenge participation (auto-generated) |
| Category | category | Free-input attribute of a challenge (VARCHAR, not a separate entity) |

## Season Icon Rules

| Season | Period | Icon | season_icon_type |
|--------|--------|------|------------------|
| Spring | Mar-May | �� | spring |
| Summer | Jun-Aug | 🌿 | summer |
| Fall | Sep-Nov | 🍁 | fall |
| Winter | Dec-Feb | ❄️ | winter |

## Calendar Display Rules

| State | Display |
|-------|---------|
| No one verified | Empty cell |
| Some verified | Verifier profile photo thumbnails |
| All verified | Season icon |

## P0 Core Flows

1. Kakao login -> profile setup -> my page
2. Challenge creation -> share invite code
3. Join challenge via invite link
4. Challenge space (calendar view)
5. Submit verification (photo + diary)
6. View verification detail + write comment
7. Challenge completion -> result screen (achievement rate, badge)

## P0 Entities

User, Challenge, ChallengeMember, Verification, DayCompletion, Comment

## MVP Excluded

Admin dashboard, rankings, in-app surveys, chat, templates, Apple login

## Tech Stack

- Frontend: Flutter (iOS/Android)
- Backend: Python FastAPI
- DB: PostgreSQL
- Auth: Kakao OAuth
