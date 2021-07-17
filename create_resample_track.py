from typing import Optional, Callable

import reapy
from reapy import reascript_api as RPR

Project = reapy.Project()


class NoTrackSelectedError(ValueError):
    ...


class ResampleTrack(reapy.Track):
    def __init__(self, source_track: reapy.Track, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.source_track = source_track

    def __repr__(self):
        return f'ResampleTrack(source_track={self.source_track.name})'

    @classmethod
    def from_source_track(cls, source_track: reapy.Track,
                          tag: str = '[RSMPL]'):
        Project.add_track(
            index=source_track.index + 1,
            name=f'{source_track.name} {tag}'
        )
        return cls(source_track=source_track,
                   id=source_track.index + 1,
                   project=source_track.project)


def create_new_rsmpl_track(parent_track: reapy.Track, route_midi: bool = True):
    if not parent_track.has_valid_id:
        raise NoTrackSelectedError('No track selected')
    track = ResampleTrack.from_source_track(parent_track)
    send = parent_track.add_send(track)
    if route_midi:
        send.set_sws_info('I_MIDI_SRCCHAN', 0)
    while track.n_fxs > 0:
        track.fxs[0].delete()
    for i, fx in enumerate(parent_track.fxs):
        if fx.index != parent_track.instrument.index:
            fx.copy_to_track(track, index=i)
    while parent_track.n_fxs > 1:
        parent_track.fxs[-1].delete()


def main():
    try:
        sel_track = Project.get_selected_track(0)

        create_new_rsmpl_track(sel_track)
    except NoTrackSelectedError as e:
        reapy.show_message_box(str(e))


if __name__ == '__main__':
    with reapy.inside_reaper():
        main()
