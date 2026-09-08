from __future__ import annotations

import asyncio
import sys
from pathlib import Path

from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine
from qasync import QEventLoop

from .controller import AppController


def main() -> int:
    app = QGuiApplication(sys.argv)
    app.setApplicationName("BeaverSearch")
    app.setOrganizationName("BeaverSearch")

    base = Path(__file__).resolve().parent
    icon = base / "assets" / "Brand" / "BeaverSearch.ico"
    if icon.exists():
        app.setWindowIcon(QIcon(str(icon)))

    loop = QEventLoop(app)
    asyncio.set_event_loop(loop)

    engine = QQmlApplicationEngine()
    controller = AppController()
    engine.rootContext().setContextProperty("appController", controller)
    engine.load(QUrl.fromLocalFile(str(base / "ui" / "main.qml")))
    if not engine.rootObjects():
        return 1

    async def bootstrap() -> None:
        await controller.initialize()

    async def cleanup() -> None:
        await controller.shutdown()

    app.aboutToQuit.connect(lambda: asyncio.create_task(cleanup()))
    with loop:
        loop.create_task(bootstrap())
        loop.run_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
