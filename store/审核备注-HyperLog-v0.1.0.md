# HyperLog 苹果审核备注草稿 · v0.1.0（2026-11-06）

> 用途：填 ASC「分发 → 版本 0.1.0 → App 审核信息 → 备注」栏（英文），答复苹果 11-06 07:31 的
> Guideline 2.1 - Information Needed - New App Submission 六项要求，然后重新提交。
> 复用：G（GrindSnore）/ Countdown Widget - Days 首次提审**主动**把同款备注写全（不等苹果问）。

## 一、要填进「备注」栏的英文正文（可直接粘贴/API 写入）

```
HyperLog (Hypermobility Log) 0.1.0 — information requested under Guideline 2.1

1) DEMO VIDEO — recorded on a physical iPhone running the latest public iOS release,
   starting from app launch and showing the typical user flow:
   <录屏链接待填>
   Flow shown: launch → Quick log (one tap) → Detailed entry (joint, pain intensity,
   duration, what was done about it, activity beforehand, Beighton 9-point
   self-assessment) → attach photos (multi-select) → entries grouped per joint →
   Report (7 days / 30 days / all): summary statistics, per-joint chart, daily trend,
   entries with photos, Beighton score → share as PDF via the iOS share sheet / mail.

2) PURPOSE AND TARGET AUDIENCE
   Audience: people with joint hypermobility — hypermobility spectrum disorder (HSD)
   and Ehlers-Danlos syndrome (EDS) — and the clinicians they see.
   Problem: hypermobile joints subluxate/dislocate frequently and episodically. Episodes
   are hard to describe and hard to recall accurately weeks later in a clinic; swelling
   photos pile up in the camera roll with no clinical context; paper diaries get abandoned.
   Value: an episode can be logged in seconds during a flare (Quick log, details later),
   photos stay attached to the entry, patterns group themselves by joint, and the user can
   hand a physiotherapist or rheumatologist one structured PDF instead of a verbal
   reconstruction. The Beighton score is captured with the entries so it does not have to be
   re-administered.

3) SETUP AND ACCESS
   No account, no sign-in, no configuration, no permissions beyond the photo library
   (requested only when the user attaches a photo). Install → open → log.
   No demo credentials are required because there is no authentication of any kind,
   and no sample files are needed because all content is created by the user on device.

4) EXTERNAL SERVICES, TOOLS AND PLATFORMS USED FOR CORE FUNCTIONALITY
   None. The app is fully offline and self-contained: no backend server, no third-party
   data provider, no authentication service, no payment processor, no AI service,
   no analytics SDK, no crash reporter, no advertising SDK, no social/login SDK.
   Storage is on-device (app sandbox). PDF rendering, chart drawing and photo handling use
   Apple frameworks only (SwiftUI / UIKit / PDFKit / PhotosUI). Exporting a report goes
   through the standard iOS share sheet or the user's own mail client — the app itself
   transmits nothing.

5) REGIONAL DIFFERENCES
   None. Features and content are identical in every territory where the app is offered.
   Localizations (English, German, French, Spanish, Japanese) are translations of the same
   feature set; no feature is enabled or disabled per region.

6) REGULATED INDUSTRY / PROTECTED THIRD-PARTY MATERIAL
   Not applicable. HyperLog is a personal record-keeping utility, not a medical device and
   not a medical service: it does not diagnose, does not treat, gives no medical advice and
   makes no clinical claims. This is stated in the App Store description and inside the app
   ("NOT A MEDICAL DEVICE — HyperLog records what you experience. It does not diagnose any
   condition. For medical concerns, consult a healthcare professional."). No protected
   third-party material is used; all icons, screenshots and text are original.

Also for clarity on the related requirements:
- Account creation is not supported, therefore no account deletion flow applies.
- There is no user-generated content shared with other users, therefore content reporting
  and blocking mechanisms do not apply.
- This version contains no in-app purchases and no paid content (Guideline 3.1.1 n/a).
- The app is a consumer utility, not an app for a specific business or its employees
  (Guideline 3.2 n/a).
- All App Store screenshots show the actual app in use (Guideline 2.3.3).
```

## 二、健哥要做的唯一一件事：真机录屏（60-90 秒）

苹果要求：**真机**（不能模拟器）+ **最新系统** + **从点开 App 那一刻开始录** + 走典型流程。
iPhone 自带录屏（控制中心圆点）即可，录完发我。分镜脚本：

| 秒 | 画面 |
|---|---|
| 0-5 | 桌面点开 HyperLog（**必须从启动开始录**） |
| 5-15 | 左下「快记」点一下 → 出现一条记录（体现"疼的时候一秒记完"） |
| 15-40 | 中间「＋」详细记录：选关节 → 疼痛强度 → 持续时长 → 处置 → 诱因 → Beighton 9 项勾选 → 存 |
| 40-55 | 打开刚存的那条 → 加照片（多选 2 张）→ 角标计数出现 |
| 55-75 | 列表页按关节分组的样子（滑一下） |
| 75-90 | 右下 More → 报告分享 → 选 30 天 → PDF 预览出现（概览/条形图/趋势/带照片）→ 停在 PDF 页 |

**不要出现**：微信/其他 App 通知弹层、真实姓名病历、其他病人信息（录前开勿扰）。

## 三、录屏怎么交给苹果（两条路，等健哥选）

- **A（推荐，我全包）**：录屏发我 → 我压到 10-20MB → 传到 VPS `postwriter.cn/review/hyperlog-demo-0.1.0.mp4` → 把链接填进上面第 1 项 → API 写入备注 → 重新提交（提交前问他一句）。
- **B**：他自己在 ASC「App 审核信息 → 附件」上传录屏文件（网页点几下），我只负责写备注文本。

## 四、这次问询的诱因（AI 侧失误，记档）

11-05 我给的提审操作卡里写"备注可填一句 No login required…**可不填**"，结果备注栏空着提交。
对**首个 App + 健康类 + 个人开发者账号**，备注栏本来就该主动写全（用途/受众/无账号/无外部服务/各地区一致）——
苹果对新 App 的 2.1 问询很大程度就是"备注栏没料"触发的。
**纠正**：G 与倒数日提审时，备注栏一律先写全再提交（模板即本文件），不等苹果问。
