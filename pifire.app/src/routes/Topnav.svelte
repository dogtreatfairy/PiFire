<script>
    import { page } from '$app/stores';
    import { modalTimer, modalServer } from '$lib/stores/modalStore';
    import { timerStatus, timerDisplay, timerUpdate, timerStop, timerPause, timerUnpause } from '$lib/timer';
    import { onMount } from 'svelte';
    import { Modal, colorMode } from '@sveltestrap/sveltestrap';
    import { pfAddress } from '$lib/stores/apiDataStore';

    $: currentTimerStatus = $timerStatus;
    $: currentTimerDisplay = $timerDisplay;

    let localPfAddress = ''; // Temporary variable to hold the value
    let selectedOption = '';

    $: if ($modalServer) {
        localPfAddress = $pfAddress;
    }

    function toggleTimerModal() {
        modalTimer.update((isOpen) => !isOpen);
    }

    function isActive(path) {
        return $page.url.pathname === path;
    }

    $: if ($modalServer) {
        if ($pfAddress === 'http://localhost') {
            selectedOption = 'localhost';
            localPfAddress = 'http://localhost';
        } else if ($pfAddress === 'http://pifire.local') {
            selectedOption = 'pifire.local';
            localPfAddress = 'http://pifire.local';
        } else {
            selectedOption = 'custom';
            localPfAddress = $pfAddress;
        }
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

<nav class="navbar navbar-expand-md py-0 border-bottom border-2 border-secondary { $colorMode === 'dark' ? 'bg-dark' : 'bg-light' }">
    <div class="container-fluid">
        <!-- Logo and Brand -->
        <div class="d-flex align-items-center order-md-first me-2">
            <a
                href="#"
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
            <!-- Timer Dynamic Section -->
            <div class="btn-group border-primary me-1" role="group" aria-label="Timer Controls">
                <!-- Timer Display -->
                <button 
                    class="btn fs-6 nav-btn-height"
                    class:btn-outline-warning={$colorMode === 'dark'}
                    class:btn-warning={$colorMode !== 'dark'}
                    class:d-none={currentTimerStatus !== 'running' && currentTimerStatus !== 'paused' && currentTimerStatus !== 'expired'}
                    on:click={toggleTimerModal}
                >
                    <span class:pulse={currentTimerStatus === 'paused' || currentTimerStatus === 'expired'}>
                        <i class="fa-solid fa-stopwatch me-2"></i><span class="fw-semibold">{currentTimerDisplay}</span>
                    </span>
                </button>
                <button
                    class="btn nav-btn-square"
                    class:btn-outline-warning={$colorMode === 'dark'}
                    class:btn-warning={$colorMode !== 'dark'}
                    class:d-none={currentTimerStatus !== 'running'}
                    on:click={timerPause}
                    aria-label="Pause Timer"
                >
                    <i class="fa-solid fa-pause"></i>
                </button>
                <button
                    class="btn nav-btn-square"
                    class:btn-outline-warning={$colorMode === 'dark'}
                    class:btn-warning={$colorMode !== 'dark'}
                    class:d-none={currentTimerStatus !== 'paused'}
                    on:click={timerUnpause}
                    aria-label="Unpause Timer"
                >
                    <i class="fa-solid fa-play"></i>
                </button>
                <button
                    class="btn nav-btn-square"
                    class:btn-outline-warning={$colorMode === 'dark'}
                    class:btn-warning={$colorMode !== 'dark'}
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
                            class="nav-link d-flex align-items-center justify-content-center nav-btn-height {isActive(link.path) ? ($colorMode === 'dark' ? 'text-warning fw-semibold' : 'text-dark fw-semibold') : ($colorMode === 'dark' ? 'text-secondary' : 'text-secondary')}"
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

<Modal body centered autofocus keyboard header="PiFire Server Address" isOpen={$modalServer} toggle={() => modalServer.set(false)}>
    <form class="modal-body">
        <div class="mb-3">
            <!-- Radio Buttons -->
            <div class="form-check mb-3 d-flex align-items-center">
                <input
                    class="form-check-input"
                    type="radio"
                    id="localhostOption"
                    name="serverAddress"
                    value="localhost"
                    bind:group={selectedOption}
                    on:change={() => localPfAddress = 'http://localhost'}
                />
                <label class="form-check-label fs-5 ms-3" for="localhostOption">
                    localhost
                </label>
            </div>
            <div class="form-check mb-3 d-flex align-items-center">
                <input
                    class="form-check-input"
                    type="radio"
                    id="pifireLocalOption"
                    name="serverAddress"
                    value="pifire.local"
                    bind:group={selectedOption}
                    on:change={() => localPfAddress = 'http://pifire.local'}
                />
                <label class="form-check-label fs-5 ms-3" for="pifireLocalOption">
                    pifire.local
                </label>
            </div>
			<div class="form-check mb-3">
				<div class="d-flex align-items-center">
					<input
						class="form-check-input"
						type="radio"
						id="customOption"
						name="serverAddress"
						value="custom"
						bind:group={selectedOption}
					/>
					<label class="form-check-label fs-5 ms-3" for="customOption">
						Custom:
					</label>
				</div>
				{#if selectedOption === 'custom'}
					<div class="mt-2">
						<input
							id="customAddressInput"
							type="text"
							class="form-control"
							bind:value={localPfAddress}
							placeholder="Enter custom address"
						/>
					</div>
				{/if}
			</div>
        </div>
    </form>
    <div class="modal-footer">
        <button
            type="button"
            class="btn btn-outline-secondary"
            on:click={() => modalServer.set(false)}
            tabindex="4"
        >
            Cancel
        </button>
        <button
            id="setServerButton"
            type="button"
            class="btn btn-primary"
            on:click={() => {
                pfAddress.set(localPfAddress);
                modalServer.set(false);
            }}
            tabindex="3"
        >
            Save
        </button>
    </div>
</Modal>