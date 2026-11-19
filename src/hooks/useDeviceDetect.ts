import { useState, useEffect } from "react";

export const useDeviceDetect = () => {
    const [isMobileOrTablet, setIsMobileOrTablet] = useState<boolean>(false);

    useEffect(() => {
        const checkDevice = () => {
            const userAgent = typeof window.navigator === 'undefined' ? '' : navigator.userAgent;
            const mobileRegex = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i;

            const isIPadOS = navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1;
            const isMobileUA = mobileRegex.test(userAgent) || isIPadOS;

            const isSmallScreen = window.innerWidth < 1024;

            setIsMobileOrTablet(isMobileUA || isSmallScreen);
        };

        checkDevice();

        window.addEventListener('resize', checkDevice);
        return () => window.removeEventListener('resize', checkDevice)
    }, []);

    return { isMobileOrTablet };
}