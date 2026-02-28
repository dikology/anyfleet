<!DOCTYPE html>

<html lang="ru"><head>
<meta charset="utf-8"/>
<meta content="width=device-width, initial-scale=1.0" name="viewport"/>
<title>Yacht Charters App</title>
<!-- Tailwind CSS -->
<script src="https://cdn.tailwindcss.com?plugins=forms,container-queries"></script>
<!-- Font Awesome for Icons -->
<link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" rel="stylesheet"/>
<!-- Custom Font -->
<link href="https://fonts.googleapis.com" rel="preconnect"/>
<link crossorigin="" href="https://fonts.gstatic.com" rel="preconnect"/>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&amp;display=swap" rel="stylesheet"/>
<script>
    tailwind.config = {
      theme: {
        extend: {
          fontFamily: {
            sans: ['Inter', 'sans-serif'],
          },
          colors: {
            'card-bg': '#1C1C1E',
            'card-bg-lighter': '#2C2C2E',
            'accent-blue': '#4CA4F4',
            'accent-blue-dark': '#0A84FF',
            'accent-green': '#32D74B',
            'accent-gold': '#FFD60A',
            'accent-red': '#FF453A',
            'text-secondary': '#8E8E93',
            'pill-bg': '#3A3A3C',
          },
          boxShadow: {
            'glow-blue': '0 0 60px -15px rgba(10, 132, 255, 0.3)',
            'glow-gold': '0 0 60px -15px rgba(255, 214, 10, 0.25)',
            'glow-red': '0 0 60px -15px rgba(255, 69, 58, 0.25)',
          }
        }
      }
    }
  </script>
<style data-purpose="custom-utilities">
    /* Hide scrollbar for clean mobile look */
    .no-scrollbar::-webkit-scrollbar {
      display: none;
    }
    .no-scrollbar {
      -ms-overflow-style: none;
      scrollbar-width: none;
    }
    
    /* Specific gradient overlays for card corners - made larger and more visible */
    .gradient-corner-blue {
      background: radial-gradient(circle at 0% 0%, rgba(76, 164, 244, 0.4) 0%, rgba(76, 164, 244, 0.1) 50%, transparent 80%);
    }
    .gradient-corner-gold {
      background: radial-gradient(circle at 0% 0%, rgba(255, 214, 10, 0.35) 0%, rgba(255, 214, 10, 0.1) 50%, transparent 80%);
    }
    .gradient-corner-red {
      background: radial-gradient(circle at 0% 0%, rgba(255, 69, 58, 0.35) 0%, rgba(255, 69, 58, 0.1) 50%, transparent 80%);
    }
  </style>
<style>
    body {
      min-height: max(884px, 100dvh);
    }
  </style>
  </head>
<body class="bg-black text-white font-sans antialiased h-screen flex flex-col overflow-hidden relative selection:bg-accent-blue selection:text-white">
<!-- BEGIN: Header -->
<!-- Contains status bar placeholder, title, add button, and sync status banner -->
<header class="px-4 pt-12 pb-4 flex-none z-10 bg-black">
<!-- Top Bar: Title & Add Button -->
<div class="flex justify-between items-center mb-6 relative">
<!-- Centered Title -->
<h1 class="text-xl font-bold uppercase tracking-widest absolute left-1/2 -translate-x-1/2">ЧАРТЕРЫ</h1>
<!-- Placeholder for left space to balance center title visually if needed, empty here -->
<div></div>
<!-- Top Right Add Button -->
<button class="w-10 h-10 rounded-full bg-[#1C1C1E] flex items-center justify-center text-accent-blue hover:bg-[#2C2C2E] transition-colors">
<i class="fa-solid fa-plus text-lg"></i>
</button>
</div>
<!-- Sync Status Banner -->
<div class="w-full bg-[#1C1C1E] rounded-xl py-3 flex items-center justify-center space-x-2">
<div class="bg-accent-green rounded-full w-5 h-5 flex items-center justify-center text-black text-xs">
<i class="fa-solid fa-check"></i>
</div>
<span class="text-gray-300 text-sm font-medium">All charters synced</span>
</div>
</header>
<!-- END: Header -->
<!-- BEGIN: Main Content -->
<!-- Scrollable list of yacht cards -->
<main class="flex-1 overflow-y-auto px-4 pb-32 no-scrollbar space-y-4">
<!-- Card 1: Public (Blue) -->
<article class="bg-card-bg rounded-2xl p-4 relative overflow-hidden group">
<!-- Ambient Glow & Gradient -->
<div class="absolute inset-0 gradient-corner-blue pointer-events-none"></div>
<!-- Card Header -->
<div class="flex items-start justify-between mb-6 relative z-10">
<!-- Tag -->
<div class="bg-blue-900/30 border border-blue-500/30 text-blue-400 px-3 py-1.5 rounded-full flex items-center space-x-2 text-sm backdrop-blur-sm">
<i class="fa-solid fa-globe"></i>
<span>Public</span>
</div>
<!-- Title & Status -->
<div class="flex-1 ml-4 text-right">
<h2 class="text-lg font-semibold text-gray-100 mb-1">Aegean Odyssey</h2>
<div class="flex items-center justify-end space-x-1.5 text-accent-green text-sm">
<i class="fa-solid fa-circle-check"></i>
<span>Synced</span>
</div>
</div>
</div>
<!-- Card Details Grid -->
<div class="grid grid-cols-[1fr_auto_1fr] items-center relative z-10">
<!-- Left Column: Departure -->
<div class="text-left">
<p class="text-[10px] uppercase text-text-secondary font-bold tracking-wider mb-1 flex items-center">
<span class="w-1.5 h-1.5 rounded-full bg-gray-600 mr-1.5"></span> DEPARTURE
          </p>
<p class="text-sm font-medium text-white mb-2">15 мая 2026 г.</p>
<div class="flex items-center space-x-1.5 text-accent-green text-xs">
<i class="fa-solid fa-circle-check"></i>
<span>Synced</span>
</div>
</div>
<!-- Center Column: Duration Pill -->
<div class="px-2">
<div class="bg-[#3D3418] text-[#FFD60A] px-3 py-1 rounded-full text-xs font-medium flex items-center space-x-1.5 whitespace-nowrap">
<i class="fa-regular fa-clock"></i>
<span>10 days</span>
</div>
</div>
<!-- Right Column: Return -->
<div class="text-right">
<p class="text-[10px] uppercase text-text-secondary font-bold tracking-wider mb-1 flex items-center justify-end">
            RETURN <span class="w-1.5 h-1.5 rounded-full bg-gray-600 ml-1.5"></span>
</p>
<p class="text-sm font-medium text-white mb-2">25 мая 2026 г.</p>
<div class="flex items-center justify-end space-x-1.5 text-text-secondary text-xs">
<i class="fa-solid fa-sailboat"></i>
<span>Lagoon 42</span>
</div>
</div>
</div>
</article>
<!-- Card 2: Community (Gold) -->
<article class="bg-card-bg rounded-2xl p-4 relative overflow-hidden"><!-- Ambient Glow & Gradient -->
<div class="absolute inset-0 gradient-corner-gold pointer-events-none"></div>
<!-- Card Header -->
<div class="flex items-start justify-between mb-6 relative z-10">
<!-- Tag -->
<div class="bg-[#3D3418] border border-yellow-600/30 text-[#CFAE48] px-3 py-1.5 rounded-full flex items-center space-x-2 text-sm backdrop-blur-sm">
<i class="fa-solid fa-user-group"></i>
<span>Community</span>
</div>
<!-- Title & Status -->
<div class="flex-1 ml-4 text-right">
<h2 class="text-lg font-semibold text-gray-100 mb-1">Baltic Explorer</h2>
<div class="flex items-center justify-end space-x-1.5 text-text-secondary text-xs">
<i class="fa-solid fa-sailboat"></i>
<span>Bavaria C42</span>
</div>
</div>
</div>
<!-- Card Details Grid -->
<div class="grid grid-cols-[1fr_auto_1fr] items-center relative z-10">
<!-- Left Column: Departure -->
<div class="text-left">
<p class="text-[10px] uppercase text-text-secondary font-bold tracking-wider mb-1 flex items-center">
<span class="w-1.5 h-1.5 rounded-full bg-gray-600 mr-1.5"></span> DEPARTURE
          </p>
<p class="text-sm font-medium text-white mb-2">01 июня 2026 г.</p>
<div class="flex items-center space-x-1.5 text-[#CFAE48] text-xs">
<i class="fa-solid fa-sun fa-spin" style="--fa-animation-duration: 10s;"></i>
<span>Pending</span>
</div>
</div>
<!-- Center Column: Duration Pill -->
<div class="px-2">
<div class="bg-[#3D3418] text-[#FFD60A] px-3 py-1 rounded-full text-xs font-medium flex items-center space-x-1.5 whitespace-nowrap">
<i class="fa-regular fa-clock"></i>
<span>7 days</span>
</div>
</div>
<!-- Right Column: Return -->
<div class="text-right">
<p class="text-[10px] uppercase text-text-secondary font-bold tracking-wider mb-1 flex items-center justify-end">
            RETURN <span class="w-1.5 h-1.5 rounded-full bg-gray-600 ml-1.5"></span>
</p>
<p class="text-sm font-medium text-white mb-2">08 июня 2026 г.</p>
<div class="flex items-center justify-end space-x-1.5 text-text-secondary text-xs">
<i class="fa-solid fa-sailboat"></i>
<span>Bavaria C42</span>
</div>
</div>
</div></article>
<!-- Card 3: Private (Red) -->
<article class="bg-card-bg rounded-2xl p-4 relative overflow-hidden"><!-- Ambient Glow & Gradient -->
<div class="absolute inset-0 gradient-corner-red pointer-events-none"></div>
<!-- Card Header -->
<div class="flex items-start justify-between mb-6 relative z-10">
<!-- Tag -->
<div class="bg-[#3A2222] border border-red-500/30 text-[#E87E76] px-3 py-1.5 rounded-full flex items-center space-x-2 text-sm backdrop-blur-sm">
<i class="fa-solid fa-lock"></i>
<span>Private</span>
</div>
<!-- Title & Status -->
<div class="flex-1 ml-4 text-right">
<h2 class="text-lg font-semibold text-gray-100 mb-1">Caribbean Escape</h2>
<div class="flex items-center justify-end space-x-1.5 text-accent-red text-sm">
<i class="fa-solid fa-triangle-exclamation"></i>
<span>Failed</span>
</div>
</div>
</div>
<!-- Card Details Grid -->
<div class="grid grid-cols-[1fr_auto_1fr] items-center relative z-10">
<!-- Left Column: Departure -->
<div class="text-left">
<p class="text-[10px] uppercase text-text-secondary font-bold tracking-wider mb-1 flex items-center">
<span class="w-1.5 h-1.5 rounded-full bg-gray-600 mr-1.5"></span> DEPARTURE
          </p>
<p class="text-sm font-medium text-white mb-2">20 июля 2026 г.</p>
<div class="flex items-center space-x-1.5 text-accent-red text-xs">
<i class="fa-solid fa-triangle-exclamation"></i>
<span>Private</span>
</div>
</div>
<!-- Center Column: Duration Pill -->
<div class="px-2">
<div class="bg-[#3A2222] text-[#FF6961] px-3 py-1 rounded-full text-xs font-medium flex items-center space-x-1.5 whitespace-nowrap">
<i class="fa-regular fa-clock"></i>
<span>14 days</span>
</div>
</div>
<!-- Right Column: Return -->
<div class="text-right">
<p class="text-[10px] uppercase text-text-secondary font-bold tracking-wider mb-1 flex items-center justify-end">
            RETURN <span class="w-1.5 h-1.5 rounded-full bg-gray-600 ml-1.5"></span>
</p>
<p class="text-sm font-medium text-white mb-2">03 августа 2026 г.</p>
<div class="flex items-center justify-end space-x-1.5 text-text-secondary text-xs">
<i class="fa-solid fa-sailboat"></i>
<span>Fountaine Pajot Isla 40</span>
</div>
</div>
</div></article>
</main>
<!-- END: Main Content -->
<!-- BEGIN: Floating Action Button -->
<button class="absolute bottom-28 right-4 w-14 h-14 rounded-full bg-accent-blue text-black flex items-center justify-center shadow-lg hover:bg-blue-400 transition-colors z-20"><i class="fa-solid fa-plus text-2xl"></i></button>
<!-- END: Floating Action Button -->
<!-- BEGIN: Bottom Navigation -->
<footer class="absolute bottom-0 w-full p-4 z-20 bg-gradient-to-t from-black via-black to-transparent">
<nav class="bg-[#1C1C1E]/90 backdrop-blur-md rounded-3xl px-4 py-3 flex justify-between items-center shadow-2xl"><!-- Nav Item: Home -->
<a class="flex flex-col items-center justify-center space-y-1 w-16 text-gray-400 hover:text-white transition-colors" href="#">
<i class="fa-solid fa-house text-xl"></i>
<span class="text-[10px] font-medium">Главная</span>
</a>
<!-- Nav Item: Charters (Active) -->
<div class="flex flex-col items-center justify-center space-y-1 w-16">
<div class="w-14 h-8 bg-accent-blue rounded-full flex items-center justify-center text-black shadow-[0_0_10px_rgba(76,164,244,0.5)]">
<i class="fa-solid fa-sailboat text-lg"></i>
</div>
<span class="text-[10px] font-medium text-accent-blue">Чартеры</span>
</div>
<!-- Nav Item: Library -->
<a class="flex flex-col items-center justify-center space-y-1 w-16 text-gray-400 hover:text-white transition-colors" href="#">
<i class="fa-solid fa-book-open text-xl"></i>
<span class="text-[10px] font-medium">Библиотека</span>
</a>
<!-- Nav Item: Discover -->
<a class="flex flex-col items-center justify-center space-y-1 w-16 text-gray-400 hover:text-white transition-colors" href="#">
<i class="fa-solid fa-globe text-xl"></i>
<span class="text-[10px] font-medium">Открытия</span>
</a>
<!-- Nav Item: Profile -->
<a class="flex flex-col items-center justify-center space-y-1 w-16 text-gray-400 hover:text-white transition-colors" href="#">
<i class="fa-solid fa-user text-xl"></i>
<span class="text-[10px] font-medium">Профиль</span>
</a></nav>
</footer>
<!-- END: Bottom Navigation -->
</body></html>