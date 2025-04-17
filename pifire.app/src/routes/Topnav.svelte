<script lang="js">
    import { darkMode, toggleTheme } from '$lib/stores/themeStore';
    import { page } from '$app/stores';
    import { modalTimer } from '$lib/stores/modalStore';
    import { timerStatus, timerDisplay, computeDisplay, timerUpdate, timerStop, timerPause, timerUnpause } from '$lib/timer';
    import { onMount } from 'svelte';
	import { browserNotificationPermission } from '$lib/notify';

    $: currentTimerStatus = $timerStatus;
    $: currentTimerDisplay = $timerDisplay;

    function toggleTimerModal() {
        modalTimer.update((isOpen) => !isOpen);
    }

    function isActive(path) {
        return $page.url.pathname === path;
    }

	function syncInterval(callback, interval) {
        const now = Date.now();
        const delay = interval - (now % interval);
        setTimeout(() => {
            callback();
            setInterval(callback, interval);
        }, delay);
    }

    onMount(() => {
		syncInterval(() => {
			timerUpdate();
		}, 1000);
    });
</script>

<nav class="navbar navbar-expand-md py-0 border-bottom border-2 border-secondary { $darkMode ? 'navbar-dark bg-dark' : 'navbar-light bg-light' }">
    <div class="container-fluid">
        <!-- Logo and Brand -->
        <div class="d-flex align-items-center order-md-first me-2">
            <a href="/">
                <img 
                    src="/static/img/logo_nt_1.svg" 
                    alt="PiFire Logo" 
                    height="30" 
                    class="me-2 my-2" 
                />
            </a>
            <a href="/" class="fw-semibold fs-4 text-decoration-none {$darkMode ? 'text-white':'text-dark'}">
                Pi<i class="text-danger">Fire</i>
            </a>
        </div>

        <div class="d-flex align-items-center justify-content-end order-md-last">
            <!-- Timer Dynamic Section -->
            <div class="btn-group border-primary me-1" role="group" aria-label="Timer Controls">
				<!-- Timer Display -->
				<button 
					class="btn fs-6 nav-btn-height"
					class:btn-outline-warning={$darkMode}
					class:btn-warning={!$darkMode}
					class:d-none={currentTimerStatus !== 'running' && currentTimerStatus !== 'paused' && currentTimerStatus !== 'expired'}
					on:click={toggleTimerModal}
				>
					<span class:pulse={currentTimerStatus === 'paused' || currentTimerStatus === 'expired'}>
						<i class="fa-solid fa-stopwatch me-2"></i><span class="fw-semibold">{currentTimerDisplay}</span>
					</span>
				</button>
				<button
					class="btn nav-btn-square"
					class:btn-outline-warning={$darkMode}
					class:btn-warning={!$darkMode}
					class:d-none={currentTimerStatus !== 'running'}
					on:click={timerPause}
					aria-label="Pause Timer"
				>
					<i class="fa-solid fa-pause"></i>
				</button>
				<button
					class="btn nav-btn-square"
					class:btn-outline-warning={$darkMode}
					class:btn-warning={!$darkMode}
					class:d-none={currentTimerStatus !== 'paused'}
					on:click={timerUnpause}
					aria-label="Unpause Timer"
				>
					<i class="fa-solid fa-play"></i>
				</button>
				<button
					class="btn nav-btn-square"
					class:btn-outline-warning={$darkMode}
					class:btn-warning={!$darkMode}
					class:d-none={currentTimerStatus !== 'running' && currentTimerStatus !== 'paused' && currentTimerStatus !== 'expired'}
					on:click={timerStop}
					aria-label="Stop Timer"
				>
					<span class:pulse={currentTimerStatus === 'finished'}><i class="fa-solid fa-stop"></i></span>
				</button>
            </div>
			<!-- Timer Button -->
			<button 
				class="btn btn-outline-secondary nav-btn-square me-1"
				class:d-none={currentTimerStatus === 'running' || currentTimerStatus === 'paused' || currentTimerStatus === 'expired'}
				on:click={toggleTimerModal}
				aria-label="Show Timer Modal"
			>
				<i class="fa-solid fa-stopwatch"></i>
			</button>

            <!-- Theme Toggle Button -->
            <div class="ms-auto">
                <button 
                    class="btn btn-outline-secondary nav-btn-square" 
                    type="button" 
                    on:click={toggleTheme}
                    aria-label="Toggle theme"
                >
                    {#if $darkMode}
                        <i class="fa-solid fa-moon"></i>
                    {:else}
                        <i class="fa-solid fa-sun"></i>
                    {/if}
                </button>
            </div>
			<!-- Navbar Toggle Button -->
			<div class="ms-1 d-md-none">
				<button 
					class="btn btn-outline-secondary nav-btn-square" 
					type="button" 
					data-bs-toggle="collapse" 
					data-bs-target="#navbarNav" 
					aria-controls="navbarNav" 
					aria-expanded="false" 
					aria-label="Toggle navigation"
				>
					<i class="fa-solid fa-bars"></i>
				</button>
			</div>
        </div>

        <!-- Navigation Links -->
		<div class="collapse navbar-collapse" id="navbarNav">
			<ul class="nav d-flex flex-column flex-md-row justify-content-center">
				{#each [
					{ path: '/', label: 'Dashboard', icon: 'fa-gauge-high' },
					{ path: '/history', label: 'History', icon: 'fa-clock' },
					{ path: '/recipe', label: 'Recipe', icon: 'fa-utensils' },
					{ path: '/settings', label: 'Settings', icon: 'fa-gear' }
				] as link}
					<li class="nav-item">
						<a
							class="nav-link d-flex align-items-center justify-content-center nav-btn-height {isActive(link.path) ? ($darkMode ? 'text-warning fw-semibold' : 'text-dark fw-semibold') : ($darkMode ? 'text-secondary' : 'text-secondary')}"
							href={link.path}
						>
							<i class={`fa-solid ${link.icon} me-1`}></i> {link.label}
						</a>
					</li>
				{/each}
			</ul>
		</div>
    </div>
</nav>