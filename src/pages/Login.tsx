import { useDeviceDetect } from "../hooks/useDeviceDetect"
import UnsupportedDevice  from "../components/UnsupportedDevice"


export default function Login() {
    const { isMobileOrTablet } = useDeviceDetect();
    if (isMobileOrTablet) {
        return <UnsupportedDevice />
    }
    return (
        <div className="min-h-screen flex flex-col">
            <main className="flex flex-1 flex-col max-w-dvh w-full mx-auto px-4 py-8 gap-30">
                <h1 className="text-5xl font-bold text-center">Motor Renting</h1>
                <form className="flex flex-col flex-1 gap-4">
                    <div className="mb-4">
                        <label className="block text-sm font-bold mb-1.5">Họ tên hoặc email</label>
                        <input type="text" name="username"
                        className="w-full border border-stone-900 rounded-lg px-3 py-2 text-black focus:outline-none" />
        
                    </div>
                    <div className="mb-4">
                        <label className="block text-sm font-bold mb-1.5">Mật khẩu</label>
                        <input type="password" name="password"
                        className="w-full border border-stone-900 rounded-lg px-3 py-2 text-black focus:outline-none" />
                    </div>
                    <div className="mb-4 flex flex-col items-center">
                        <button type="submit" className="w-[20%] py-3 bg-[#0068EF]
                         text-white font-medium rounded-lg cursor-pointer text-center">
                         Đăng nhập
                        </button>
                    </div>
                
                </form>
            </main>
        </div>
    )
}