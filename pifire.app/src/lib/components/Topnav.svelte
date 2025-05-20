<script>
    import { page } from '$app/stores';
    import { modalTimer, modalServer } from '$lib/stores/modalStore';
    import { Modal, colorMode } from '@sveltestrap/sveltestrap';
    // controlData is used for general backend state
    import { serverAddress, switchServer, controlData } from '$lib/stores/socketioStore'; 
    import { get } from 'svelte/store';
    // Import necessary stores and functions from the new timer.js
    import { 
        timerStore,         // Main store for status, display, hours, minutes, options
        timerMode,          // Derived store for status string: 'running', 'paused', 'stopped', 'expired'
        initTimerModule,  
        destroyTimerModule, 
        pauseTimer,         // Control function to pause
        resumeTimer,        // Control function to resume
        stopTimer           // Control function to stop
    } from '$lib/timer';     // Path to your new timer.js (svelte_timer_store_v2)
    import { onMount, onDestroy } from 'svelte';

    onMount(() => {
        initTimerModule(); // Initialize the timer module logic on the client
    });

    onDestroy(() => {
        destroyTimerModule(); // Clean up timer module subscriptions and intervals
    });

    let localserverAddress = '';
    let selectedOption = '';

    // Use the exported timerMode store for UI status logic.
    // Provide a default if $timerMode is undefined during SSR.
    $: timerStatusUIText = $timerMode ?? 'stopped'; 

    // Use the direct display string from timerStore.
    // Provide defaults using optional chaining and nullish coalescing for SSR safety.
    $: currentTimerDisplay = $timerStore?.display ?? '--:--:--';

    // Derive shutdown/keepwarm status display from the timerStore fields.
    // Provide defaults for SSR safety.
    $: showTimerShutdownIcon = $timerStore?.isShutdownSet ?? false;
    $: showTimerKeepWarmIcon = $timerStore?.isKeepWarmSet ?? false;

    $: if (get(modalServer)) {
        localserverAddress = get(serverAddress);
        if (get(serverAddress) === 'http://localhost') {
            selectedOption = 'localhost';
        } else if (get(serverAddress) === 'http://pifire.local') {
            selectedOption = 'pifire.local';
        } else {
            selectedOption = 'custom';
        }
    }

    function isActive(path) {
        return $page.url.pathname === path;
    }

    // Debugging logs (optional, can be removed for production)
    $: if(typeof window !== 'undefined') { // Ensure logs only run client-side
        // console.log('Topnav Debug - Timer Status UI Text ($timerMode):', timerStatusUIText);
        // console.log('Topnav Debug - Timer Display ($timerStore?.display):', currentTimerDisplay);
        // console.log('Topnav Debug - Raw $timerStore:', $timerStore);
        // console.log('Topnav Debug - Show Timer Shutdown Icon ($timerStore?.isShutdownSet):', showTimerShutdownIcon);
        // console.log('Topnav Debug - Show Timer Keep Warm Icon ($timerStore?.isKeepWarmSet):', showTimerKeepWarmIcon);
    }

</script>

<nav class="navbar navbar-expand-md py-0 border-bottom border-2 border-secondary fixed-top { $colorMode === 'dark' ? 'bg-dark' : 'bg-light' }">
    <div class="container-fluid">
        <div class="d-flex align-items-center order-md-first me-2">
            <a
                href="/server-settings" 
                on:click|preventDefault={() => modalServer.set(true)}
                role="button"
                aria-label="Open PiFire Server Address Modal"
            >
                <img
                    src="/img/logo_nt_1.svg"
                    alt="PiFire Logo"
                    height="30"
                    class="me-2 my-2"
                />
            </a>
            <a href="/" class="fw-semibold fs-4 text-decoration-none {$colorMode === 'dark' ? 'text-white' : 'text-dark'}">
                Pi<i class="text-danger">Fire</i>
            </a>
        </div>
        
        <div class="d-flex align-items-center justify-content-end order-md-last">
            <div class="btn-group border-primary me-1" role="group" aria-label="Timer Controls">
                <button
                    class="btn fs-6 nav-btn-height {timerStatusUIText === 'stopped' ? 'd-none' : ''}"
                    class:btn-outline-warning={$colorMode === 'dark'}
                    class:btn-warning={$colorMode !== 'dark'}
                    on:click={() => modalTimer.set(true)} title="Timer Status / Settings"
                >
                    <span class:pulse={timerStatusUIText === 'paused' || timerStatusUIText === 'expired'}>
                        <i class="fa-solid fa-stopwatch me-2"></i>
                        <span class="fw-semibold">{currentTimerDisplay}</span>
                    </span>
                
                    {#if showTimerShutdownIcon}
                        <span 
                            class="badge ms-2 text-dark" 
                            class:bg-warning={$colorMode === 'dark'}
                            class:bg-dark={$colorMode !== 'dark'}
                            title="Shutdown on Timer End">
                            <i class="fas fa-power-off"></i>
                        </span>
                    {/if}
                    {#if showTimerKeepWarmIcon}
                        <span 
                            class="badge ms-1 text-dark" 
                            class:bg-warning={$colorMode === 'dark'}
                            class:bg-dark={$colorMode !== 'dark'}
                            title="Keep Warm on Timer End">
                            <i class="fas fa-thermometer-half"></i>
                        </span>
                    {/if}
                </button>

                <button
                    class="btn nav-btn-square {timerStatusUIText === 'running' ? '' : 'd-none'}"
                    class:btn-outline-warning={$colorMode === 'dark'}
                    class:btn-warning={$colorMode !== 'dark'}
                    on:click={pauseTimer} aria-label="Pause Timer" title="Pause Timer"
                >
                    <i class="fa-solid fa-pause"></i>
                </button>

                <button
                    class="btn nav-btn-square {timerStatusUIText === 'paused' ? '' : 'd-none'}"
                    class:btn-outline-warning={$colorMode === 'dark'}
                    class:btn-warning={$colorMode !== 'dark'}
                    on:click={resumeTimer} aria-label="Resume Timer"
                    title="Resume Timer"
                >
                    <i class="fa-solid fa-play"></i>
                </button>

                <button
                    class="btn nav-btn-square {timerStatusUIText === 'stopped' ? 'd-none' : ''}"
                    class:btn-outline-warning={$colorMode === 'dark'}  
                    class:btn-warning={$colorMode !== 'dark'} 
                    on:click={stopTimer} aria-label="Stop Timer / Clear Alarm"
                    title="Stop Timer / Clear Alarm"
                >
                    <span class:pulse={timerStatusUIText === 'expired'}><i class="fa-solid fa-stop"></i></span>
                </button>
            </div>

            <button
                class="btn btn-outline-secondary nav-btn-square me-1 {timerStatusUIText === 'stopped' ? '' : 'd-none'}"
                on:click={() => modalTimer.set(true)}
                aria-label="Set Timer"
                title="Set Timer"
            >
                <i class="fa-solid fa-stopwatch"></i>
            </button>

            <div class="ms-auto">
                <button
                    class="btn btn-outline-secondary nav-btn-square"
                    type="button"
                    on:click={() => ($colorMode = $colorMode === 'dark' ? 'light' : 'dark')}
                    aria-label="Toggle theme"
                >
                    {#if $colorMode === 'dark'}
                        <i class="fa-solid fa-moon"></i>
                    {:else}
                        <i class="fa-solid fa-sun"></i>
                    {/if}
                </button>
            </div>
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
                            class="nav-link d-flex align-items-center justify-content-center nav-btn-height {isActive(link.path) ? ($colorMode === 'dark' ? 'text-warning fw-semibold' : 'text-dark fw-semibold') : ($colorMode === 'dark' ? 'text-secondary' : 'text-secondary')}"
                            href={link.path}
                        >
                            <i class="fa-solid {link.icon} me-1"></i> {link.label}
                        </a>
                    </li>
                {/each}
            </ul>
        </div>
    </div> 
</nav>

<Modal body centered keyboard header="PiFire Server Address" isOpen={$modalServer} toggle={() => modalServer.set(false)}>
    <form class="modal-body" on:submit|preventDefault> 
        <div class="mb-3">
            <div class="form-check mb-3 d-flex align-items-center">
                <input
                    class="form-check-input" type="radio" id="localhostOption" name="serverAddressOptions" 
                    value="localhost" bind:group={selectedOption} on:change={() => localserverAddress = 'http://localhost'}
                />
                <label class="form-check-label fs-5 ms-3" for="localhostOption"> localhost </label>
            </div>
            <div class="form-check mb-3 d-flex align-items-center">
                <input
                    class="form-check-input" type="radio" id="pifireLocalOption" name="serverAddressOptions" 
                    value="pifire.local" bind:group={selectedOption} on:change={() => localserverAddress = 'http://pifire.local'}
                />
                <label class="form-check-label fs-5 ms-3" for="pifireLocalOption"> pifire.local </label>
            </div>
            <div class="form-check mb-3">
                <div class="d-flex align-items-center">
                    <input
                        class="form-check-input" type="radio" id="customOption" name="serverAddressOptions" 
                        value="custom" bind:group={selectedOption}
                    />
                    <label class="form-check-label fs-5 ms-3" for="customOption"> Custom: </label>
                </div>
                {#if selectedOption === 'custom'}
                    <div class="mt-2">
                        <input
                            id="customAddressInput" type="text" class="form-control" bind:value={localserverAddress}
                            placeholder="Enter custom address e.g., http://192.168.1.x"
                        />
                    </div>
                {/if}
            </div>
        </div>
    </form>
    <div class="modal-footer">
        <button type="button" class="btn btn-outline-secondary" on:click={() => modalServer.set(false)}> Cancel </button> 
        <button
            id="setServerButton" type="button" class="btn btn-primary" 
            on:click={() => {
                switchServer(localserverAddress); 
                modalServer.set(false);
            }}
        > Save </button> 
    </div>
</Modal>
