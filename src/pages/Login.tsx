import { useDeviceDetect } from "../hooks/useDeviceDetect"
import UnsupportedDevice  from "../components/UnsupportedDevice"


export default function Login() {
    const { isMobileOrTablet } = useDeviceDetect();
    if (isMobileOrTablet) {
        return <UnsupportedDevice />
    }
    return (
        <div>Welcome to Motor Renting</div>
    )
}