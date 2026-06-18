---
title: Things that hold still
slug: things-that-hold-still
date: 2026-06-16
description: Eight photographs. No common subject — except the moment just before
  things move again.
tags:
- australia
- japan
- london
- photography
- travel
topics:
- photography
image_url: https://media.publit.io/file/IMG-0692-001.jpg
image_focal_point: center center
use_featured_image: true
layout: photo-essay
draft: true
---

Eight photographs. No common subject — except the moment just before things move again.

I don't shoot to document. I shoot because occasionally something in the world arranges itself into a shape I want to keep, and I have a few seconds to decide whether I'm quick enough.

---

![Sunrise over waves at South Curl Curl Beach](https://media.publit.io/file/IMG-0692-001.jpg)

*South Curl Curl, May 2026*

Six-thirty in the morning. I'd driven up from the northern suburbs in the dark and arrived just as the sky was making up its mind. The waves were doing their ordinary thing, entirely unimpressed. There's something I find clarifying about the beach at this hour — the world is at work but hasn't started talking yet.

---
<figure class="figure--portrait">
  <img src="https://media.publit.io/file/Hammersmith-Reflections-1.jpeg" alt="...">
  <figcaption>Wet pavement reflections at night on a London street</figcaption>
</figure>
*Hammersmith, November 2022*

Out of a concert at the Lyric and into rain-wet streets. The pavement holds more light than the sky does in November. I stopped without thinking — there's a bus just out of frame, and the blur in the reflection is its doing. Too still and this would be a study; the motion makes it a moment.

---

![Shadow of two people with a track across the field ahead of them](https://live.staticflickr.com/3011/2563687737_1e89d6b632_c.jpg)

*UK Coast to Coast, 2008*

Day four, somewhere on the approach to Keld. We'd been walking since first light and our shadows had been with us all morning, stretching ahead like scouts. My companion didn't know I'd made the frame. I waited for the shadows to align with the track.

---

![Two people walking with arms folded matching the toad statue ahead of them](https://media.publit.io/file/Matsumoto-Arms.jpeg)

*Matsumoto, Japan, 2012*

This one took no patience at all — it was just there. Two people walked past a toad sculpture with their arms folded in precisely the same way, and I had the camera up in time. Whether they noticed the frog or were unconsciously imitating it I never found out. I only had one frame.

---

![A person working in a Japanese garden](https://media.publit.io/file/garden-worker-japan.jpeg)

*Japan, 2012*

The Japanese relationship to maintenance is unlike anything I've seen elsewhere. This person was raking with a concentration that looked, from outside, identical to prayer. I shot from a distance and didn't move closer.

---

![A ceremonial rope at a temple in Kyoto](https://media.publit.io/file/Ceremonial-Rope.jpeg)

*Kyoto, September 2012*

Fushimi Inari, early morning before the crowds. The rope is part of a boundary marker — functional, not decorative — but it has that particular quality of Japanese craft where the functional thing turns out to be beautiful anyway. The light was wrong for everything except this.

---

![An aqueduct with repeating arches](https://media.publit.io/file/Aquaduct.jpeg)

*Kyoto, September 2012*

The Suirokaku aqueduct. I walked it twice before I found the angle where the rhythm of the arches resolved into something that wanted to be a photograph. Repetition is interesting when there's just enough variation to stop it becoming pattern.

---

![Close-up of red berries with dew drops](https://media.publit.io/file/berries-f.jpeg)

*Cotswolds Way, November 2007*

Shot on a Ricoh GX100 in macro mode, kneeling in mud on a cold morning. The dew was already going — by the time I'd found my footing and composed the frame there were half as many drops as when I first saw it. That's always the deal with close work: the world is drying out while you fumble with the camera.

---

Eight photographs, then. Shot over nineteen years on cameras ranging from a compact Ricoh to an iPhone Pro. What they have in common is that I was somewhere specific, paying enough attention to see them.

That's the whole of it.

---

*All photographs by William Pickup.*

## How photo-essay layout serves this post

The `photo-essay` layout is built for posts where images and prose share equal weight — neither illustrating the other but running alongside. Key points:

- `$LayoutStyle = "photo-essay"` applies the wider content column and the alternating image/text rhythm
- No hero image treatment — the layout begins with text, and each image arrives in sequence within the body
- `$UseFeaturedImage = true` still set so the post has a representative image for the blog index card; the `post-hero-image` block is suppressed by the layout CSS (images sit inside the body instead)
- Inline images use standard Markdown `![]()` syntax — the `photo-essay` CSS handles their sizing and spacing
- `$LayoutAccent` left empty here — the images supply their own colour energy; an accent would compete

### Inline image sizing

Within a `photo-essay` post the default image treatment is full column-width. To vary rhythm you can use figure classes in HTML blocks:

```html
<figure class="figure--wide">
  <img src="https://media.publit.io/file/example.jpeg" alt="...">
  <figcaption>Optional caption</figcaption>
</figure>
```

Or for a pair of images side by side:

```html
<div class="photo-pair">
  <figure><img src="..." alt="..."></figure>
  <figure><img src="..." alt="..."></figure>
</div>
```

The `photo-pair` class (defined in the magazine layout CSS block) sets a two-column grid that collapses to single column below 640px.
